.. title: Denver PTG Summary: Ironic (part 2)
.. slug: ironic-ptg-denver-2017-2
.. date: 2017-10-05 17:42:52 UTC+02:00
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

Future of bare metal scheduling
-------------------------------

We have discussed the present and the future of scheduling bare metal
instances using nova. The discussion has started in the nova room and
continued in our room afterwards and on Friday.

Node availability
~~~~~~~~~~~~~~~~~

First, we discussed marking a node as unavailable for nova. Currently, when a
node is cleaning or otherwise unavailable, we set its resource classes count
to zero. This is, of course, hacky, and we want to get rid of it. I was
thinking about a new virt driver method to express availability, like

.. code-block:: python

    def is_operational(self, hostname):
        "Returns whether the host can be used for deployment."""

However, it was pointed out that ironic would probably be the only user of
such feature. Instead, it was proposed to use ``RESERVED`` field when
reporting resource classes. Indeed, cleaning can be treated as a temporary
reservation of the node by ironic for its internal business. We will return
``RESERVED=0`` when node is active or available, and ``RESERVED=TOTAL``
otherwise.

Advanced configuration
~~~~~~~~~~~~~~~~~~~~~~

Then we discussed means of passing from nova to ironic such information as
BIOS configuration or requested RAID layout. We agreed (again) that we don't
want nova to just pipe JSON blobs from a user to ironic. Instead, we will use
*traits* on the nova side and a new entity tentatively called *deploy
templates* on the ironic side.

A user will request a *deploy template* to be applied on a node by requesting
an appropriate trait. All matches traits will be passed from nova to ironic in
a similar way to how capabilities are passed now. Then ironic will fetch
*deploy templates* corresponding to traits and apply them.

The exact form of a *deploy template* is to be defined. A *deploy template*
will probably contain a *deploy step* name and its arguments. Thus, this work
will require the *deploy steps* work to be revived and finished.

**johnthetubaguy** will write specs on both topics.

Ownership of bare metal nodes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We want to allow nodes to be optionally owned by a particular tena^Wproject.
We discussed how to make the nova side work, with ironic still being the source
of truth for who owns which node. We decided that we can probably make it work
with *traits* as well.

Quantitative scheduling
~~~~~~~~~~~~~~~~~~~~~~~

Next, by request of some of the community members, we have discussed bringing
back the ability to use quantitative scheduling with bare metal instances.
We ended up with the same outcome as previously. Starting with Pike, bare
metal scheduling has to be done in terms of *custom resource classes* and
*traits* (ah, that magical traits!), and quantitative scheduling is not
coming back.

Inspection and resource classes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After the switch to resource classes inspection is much less useful.
Previously the information it provided was enough for scheduling. Now we don't
care too much about CPU/memory/disk properties, but we do care about the
resource class. Essentially, inspection is only useful for discovering ports
and capabilities.

In-band inspection (using ironic-inspector) has a good work-around though: its
*introspection rules* (mini-DSL to run on the discovered data) can be used to
set the resource class based on logic provided by an operator. These rules are
part of the ironic-inspector API, and thus out-of-band inspection does not
benefit from them.

A potential solution is to move introspection rules API to ironic itself. That
would require agreeing on a common inventory format for both in-band and
out-of-band inspection. This is likely to be the `IPA inventory format`.
Then we'll have to change the *inspect* interface. Currently we have one call
that does the whole inspection process, we need a call that returns
an inventory. Then ironic itself will run introspection rules, create ports
and update properties and capabilities.

A big problem here is that the discovery process, implemented purely within
ironic-inspector, also heavily relies on introspection rules. We cannot
remove/deprecate the introspection rules API in ironic-inspector until this is
solved. The two API will have to co-exist for the time being. We should
probably put the mechanism behind introspection rules to ironic-lib.

**sambetts** plans to summarize a potential solution on the ML.

We also discussed potentially having the default resource class to use for new
nodes, if none is provided. That would simplify things for some consumers,
like TripleO. Another option is to generate a resource class based on some
template. We can even implement both:

.. code-block:: ini

    default_hardware_type = baremetal

results in ``baremetal`` resource class for new nodes, while

.. code-block:: ini

    inspected_hardware_type = bm-{memory_mb}-{cpus}-{cpu_arch}

results in a templated resource class to be set for inspected nodes that do
not have a resource class already set.

.. _IPA inventory format: https://docs.openstack.org/ironic-python-agent/latest/admin/how_it_works.html#hardware-inventory

Future ironic-inspector architecture
------------------------------------

The discussion in `Inspection and resource classes`_ brought us to an idea of
slowly merging most of ironic-inspector into ironic. Ironic will benefit by
receiving introspection rules and optional inventory storage, while
ironic-inspector will benefit from using the boot interface and from the
existing HA architecture. In the end, the only part remaining in a separate
project will be PXE handling for introspecting of nodes without ports and
for auto-discovery.

It's not clear how that will look. We could not discuss it in-depth, as a core
contributor (**milan**) was not able to come to the PTG. However, we have a
rough plan for the next steps:

#. Implement optional support for using boot interfaces in the ``Inspector``
   *inspect* interface: https://review.openstack.org/305864.

   When discussing its technical details, we agreed that instead of having a
   configuration option in ironic to force using a boot interface, we better
   introduce a configuration option in ironic-inspector to completely disable
   its boot management.

#. Implement optional support for using network interfaces in the ``Inspector``
   *inspect* interface: https://review.openstack.org/320003.

#. Move introspection rules to ironic itself as discussed in `Inspection
   and resource classes`_.

#. Move the whole data processing to ironic and stop using ironic-inspector
   when a boot interface has all required information.

The first item is planned for Queens, the second can fit as well. The timeline
for the other items is unclear. A separate call will be scheduled soon to
discuss this.

BIOS configuration
------------------

This feature has been discussed several times already. This time we came up
with a more or less solid plan to implement it in Queens.

* We have confirmed the current plan to use clean steps for starting the
  configuration, similar how RAID already works. There will be two new clean
  steps: ``bios.apply_configuration`` and ``bios.factory_reset``.

* We discussed having a new BIOS interface versus introducing new methods on
  the management interface. We agreed that we want to allow mix-and-match of
  interfaces, e.g. using Redfish power with a vendor BIOS interface.

* We also discussed the name of the new interface. While the name "BIOS" is
  not ideal, as some systems use UEFI and some don't even have a BIOS, we
  could not come up with a better proposal.

* We will apply only very minimum validation to requested parameters.

Eventually, we will want to expose this feature as a deploy step as well.

A point of contention was how to display available BIOS configuration to a
user. Vendor representatives told us that available configurable parameters
may vary from node to node even within the same generation, so doing it
per-driver is not an option. We decided to go with the following approach:

* Introduce a new API endpoint to return cached available parameters. The
  response will contain the standard ``updated_at`` field, informing a user
  when the cache was last updated.

* The cache will be updated every time the configuration is changed via
  the clean steps mentioned above.

* The cache will also be updated on moving a node from ``enroll`` to
  ``manageable`` provision states.

API for single request deploy
-----------------------------

This idea has been in the air for really long time. Currently, a deployment
via the ironic API involves:

* locking a node by setting ``instance_uuid``,
* attaching VIFs via the VIF API,
* updating ``instance_info`` with a few fields,
* requesting provision state ``active``, providing a configdrive.

In addition to being not user-friendly, this complex procedure makes it harder
to configure policies in a way to allow a user to only deploy/undeploy nodes
and nothing else.

Essentially, three ideas where considered:

#. Introduce a completely new API endpoint. This may complicate our already
   quite complex API.

#. Make working with the exising node more restful. For example, allow a PUT
   request against a node updating both ``instance_uuid`` and
   ``instance_info``, and changing ``provision_state`` to ``active``.

   It was noted, however, that directly changing ``provision_state`` is
   confusing, as the result will not match it (the value of ``provision_state``
   will become ``deploying``, not ``active``). This can be fixed by setting
   ``target_provision_state`` instead.

#. Introduce a new *deployment* object and CRUD API associated with it. A UUID
   of this object will replace ``instance_uuid``, while its body will contain
   what we have in ``instance_info`` now. A deploy request would look like::

    POST /v1/deployments {'node_uuid': '...', 'root_gb': '...', 'config_drive': '...'}

   A request to undeploy will be just::

    DELETE /v1/deployments/<DEPLOY UUID>

   Finally, and update of this object will cause a reprovision::

    PUT /v1/deployments/<DEPLOY UUID> {'config_drive': '...'}

   This is also a restful option, which is also the hardest to implement.

We did not agree to implement any (or some) of these options. Instead,
**pas-ha** will look into possible policies adjustments to allow a non-admin
user to provision and unprovision instances. A definition of success is to be
able to switch nova to a non-admin user.
