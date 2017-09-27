.. title: Denver PTG Summary: Ironic (part 2)
.. slug: ironic-ptg-denver-2017-2
.. date: 2017-09-27 15:42:52 UTC+02:00
.. tags: software, openstack
.. category: 
.. link: 
.. description: 
.. type: text

Denver PTG Summary: Ironic (part 2)
===================================

This is an extract from my personal notes and `public etherpads`_ from the
OpenStack PTG 2017 in Denver. A lot of text ahead!

This part covers contentions topics and future features discussion, as well as
a summary of our Queens priorities.

:doc:`Previous part <ironic-ptg-denver-2017-1>`.

.. _public etherpads: https://etherpad.openstack.org/p/ironic-queens-ptg

.. TEASER_END: Read more

Nova virt driver API compatibility
----------------------------------

Currently, we hardcode the required Bare Metal API microversion in our virt
driver. This introduces a hard dependency on a certain version of ironic, even
when it is not mandatory in reality, and enforces a particular upgrade order
between nova and ironic. For example, when we introduced boot-from-volume
support, we had to bump the required version, even though the feature itself
is optional. Cinder support, on the other hand, has multiple code paths
in nova, depending on which API version is available.

We would like to support the current and the previous versions of ironic in
the virt driver. For that we will need more advanced support for API
microversion negotiation in *ironicclient*. Currently it's only possible to
request one version during client creation. What we want to end up with is to
request the **minimum** version in get_client_, and then provide an ability
to specify a version in each call. For example,

.. code-block:: python

    ir_client = ironicclient.get_client(session=session,
                                        os_ironic_api_version="1.28")
    nodes = ir_client.node.list()  # using 1.28
    ports = ir_client.port.list(os_ironic_api_version="1.34")  # overriding

Another idea was to allow specifying several versions in get_client_. The
highest available version will be chosen and used for all calls:

.. code-block:: python

    ir_client = ironicclient.get_client(session=session,
                                        os_ironic_api_version=["1.28", "1.34"])
    if ir_client.negotiated_api_version == (1, 34):
        # do something

Nothing prevents us from implementing both, but the former seems to be what
the API SIG recommends (unofficially, **dtantsur** to follow up with a formal
guideline). It seems that we can reuse newly introduces version discovery
support from the *keystoneauth1* library. **TheJulia** will look into it.

.. _get_client: https://docs.openstack.org/python-ironicclient/latest/api/ironicclient.client.html

What we consider a deploy?
--------------------------

We had a heated discussion on our deploy interfaces. Currently, the whole
business logic of provisioning, unprovisioning, taking over and cleaning nodes
is spread between the conductor and a deploy driver, with the deploy driver
containing the most of it. This ends up with a lot of duplication, and also
with vendor-specific deploy interfaces, which is something we would want to
avoid. It also ends up with a lot of conditionals in the deploy interfaces
code, as e.g. boot-from-volume does not need half of the actions.
A few options were considered without a clear winner:

#. Move orchestration to the conductor, keep only image flashing logic in
   deploy interfaces. This is arguably how we planned on using deploy
   interfaces. But doing so would limit the ability of drivers to change how
   deploy if orchestrated, if e.g. they need to change the order of some
   operations or add a driver-specific operation in between of them.

#. Create a new *orchestration* interface, keep only image flashing logic in
   deploy interfaces. That will fix the problem with customization, but it
   will complicate our interfaces matrix even further. And such change would
   break all out-of-tree drivers with custom deploy interfaces.

#. Do nothing and just try our best to clean up the duplication.

The last option is what we're going to do for Queens. Then we will re-evaluate
the remaining options.

Available clean steps API
-------------------------

We have currently no way to indicate which clean steps are available for which
node. Implementing such API is complicated by the fact that some clean steps
come from hardware interfaces, while some come from the ramdisk (at least for
IPA-based drivers). The exact API was discussed in the API SIG room, and then
later in the ironic room.

We agreed that clean steps need to be cached to make sure we can return them
in a synchronous GET request, like ``GET /v1/nodes/<UUID>/cleaning/steps``
(the exact URI to be discussed in the spec). The caching itself will happen in
two cases:

#. Implicitly on every cleaning
#. Explicitly when a user requests manual cleaning without clean steps

A standard ``update_at`` field will be provided, so that users know when the
cached steps were last updated. **rloo** to follow up on the spec with it.

We decided to not take any actions to invalidate the cache for now.

Rethinking the vendor passthru API
----------------------------------

Two problems were discussed:

#. For dynamic drivers, the driver vendor passthru API only works with
   the default *vendor* interface implementation
#. No more support for mixing several vendor passthru implementations

For the first issue, we probably need to do the same thing as we plan to do
with driver properties: https://review.openstack.org/#/c/471174/. This does
not seem to be a high priority, so **dtantsur** will just file an RFE and
leave it there.

For the second issue, we don't have a clean solution now. It can be worked
around by changing ``node.vendor_interface`` on flight. **pas-ha** will
document it.
