.. title: Atlanta PTG Summary: Ironic (part 4)
.. slug: ironic-ptg-atlanta-2017-4
.. date: 2017-03-08 15:25 UTC+01:00
.. tags: software, openstack
.. category: 
.. link: 
.. description: 
.. type: text

This is an extract from my personal notes and public etherpads from the
OpenStack PTG 2017 in Atlanta. A lot of text ahead!

`The previous part <../posts/ironic-ptg-atlanta-2017-3.html>`_.

.. TEASER_END: Read more

Future Work (cont)
------------------

Etherpad: https://etherpad.openstack.org/p/ironic-pike-ptg-future-work.

Deploy-time RAID
~~~~~~~~~~~~~~~~

This was discussed on the last design summit. Since then we've got a `nova
spec <https://review.openstack.org/408151>`_, which, however, hasn't got many
reviews so far. The spec continues using ``block_device_mapping_v2``, other
options apparently were not considered.

We discussed how to inform Nova whether or not RAID can be built for
a particular node. Ideally, we need to tell the scheduler about many things:
RAID support, disk number, disk sizes. We decided that it's an overkill, at
least for the beginning. We'll only rely on a "supports RAID" trait for now.

It's still unclear what to do about ``local_gb`` property, but with planned
Nova changes it may not be required any more.

Advanced partitioning
~~~~~~~~~~~~~~~~~~~~~

There is a desire for flexible partitioning in ironic, both in case of
partition and whole disk images (in the latter case - partition other disks).
Generally, there was no consensus on the PTG. Some people were very much in
favor of this feature, some - quite against. It's unclear how to pass
partitioning information from Nova. There is a concern that such feature will
get us too much into OS-specific details. We agreed that someone interested
will collect the requirements, create a more detailed proposal, and we'll
discuss it on the next PTG.

Splitting nodes into separate pools
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This feature is about dedicating some nodes to a tenant, essentially adding a
tenant_id field to nodes. This can be helpful e.g. for a hardware provider to
reserve hardware for a tenant, so that it's always available.

This seems relatively easy to implement in Ironic. We need a new field on
nodes, then only show non-admin users their hardware. A bit trickier to make
it work with Nova. We agreed to investigate passing a token from Nova to
Ironic, as opposed to always using a service user admin token.

Actions
    **vdrok** to work out the details and propose a spec.

Requirements for routed networks
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We discussed requirements for achieving routed architecture like
spine-and-leaf. It seems that most of the requirements are already in our
plans. The outstanding items are:

* Multiple subnets support for ironic-inspector. Can be solved in
  ``dnsmasq.conf`` level, an appropriate change was merged into
  puppet-ironic.

* Per-node provision and cleaning networks. There is an RFE, somebody just
  has to do the work.

This does not seem to be a Pike goal for us, but many of the dependencies
are planned for Pike.

Configuring BIOS setting for nodes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Preparing a node to be configured to serve a certain rule by tweaking its
settings. Currently, it is implemented by the Drac driver in a vendor pass-thru.

We agreed that such feature would better fit cleaning, rather then
pre-deployment. Thus, it does not depend on deploy steps. It was suggested to
extend the management interface to support passing it an arbitrary JSON with
configuration. Then a clean step would pick it (similar to RAID).

Actions
    **rpioso** to write a spec for this feature.

Deploy steps
~~~~~~~~~~~~

We discussed `the deploy steps proposal <https://review.openstack.org/412523>`_
in depth. We agreed on partially splitting the deployment procedure into
pluggable bits. We will leave the very core of the deployment - flashing the
image onto a target disk - hardcoded, at least for now. The drivers will be
able to define steps to run before and after this core deployment. Pre- and
post-deployment steps will have different priorities ranges, something like::

    0 < pre-max/deploy-min < deploy-max/post-min < infinity

We plan on making partitioning a pre-deploy step, and installing a bootloader
a post-deploy step. We will not allow IPA hardware managers to define deploy
steps, at least for now.

Actions
    **yolanda** is planning to work on this feature, **rloo** and **TheJulia**
    to help.

Authenticating IPA
~~~~~~~~~~~~~~~~~~

IPA HTTP endpoints, and the endpoints Ironic provides for ramdisk callbacks
are completely insecure right now. We hesitated to add any authentication to
them, as any secrets published for the ramdisk to use (be it part of kernel
command line or image itself) are readily available to anyone on the network.

We agreed on several things to look into:

* A random CSRF-like token to use for each node. This will somewhat limit the
  attack surface by requiring an attacker to intercept a token for the
  specific node, rather then just access the endpoints.

* Document splitting out public and private Ironic API as part of our future
  reference architecture guide.

* Make sure we support TLS between Ironic and IPA, which is particularly
  helpful when virtual media is used (and secrets are not leaked).

Actions
    **jroll** and **joanna** to look into the random token idea.
    **jroll** to write an RFE for TLS between IPA and Ironic.

Smaller things
~~~~~~~~~~~~~~

Using ansible-networking as a ML2 driver for ironic-neutron integration work
    It was suggested to make it one of backends for
    ``networking-generic-switch`` in addition to ``netmiko``. Potential
    concurrency issues when using SSH were raised, and still require a solution.

Extending and standardizing the list of capabilities the drivers may discover
    It was proposed to use `os-traits <https://github.com/jaypipes/os-traits>`_
    for standardizing qualitative capabilities. **jroll** will look into
    quantitative capabilities.

Pluggable interface for long-running processes
    This was proposed as an optional way to mitigate certain problems with
    local long-running services, like console. E.g. if a conductor crashes,
    its console services keep running. It was noted that this is a bug to be
    fixed (**TheJulia** volunteered to triage it).
    The proposed solution involved optionally run processes on a remote
    cluster, e.g. k8s. Concerns were voiced on the PTG around complicating
    support matrix and adding more decisions to make for operators.
    There was no apparent consensus on implementing this feature due to that.

Setting specific boot device for PXE booting
    It was found to be already solved by setting ``pxe_enabled`` on ports.
    We just need to update ironic-inspector to set this flag.

Priorities and planning
-----------------------

The suggested priorities list is now finalized in
https://review.openstack.org/439710.

We also agreed on the following priorities for ironic-inspector subteam:

* Inspector HA (**milan**)
* Community goal - python 3.5 (**JayF**, **hurricanerix**)
* Community goal - devstack+apache+wsgi (**aarefiev**, **ovoshchana**)
* Inspector needs to update ``pxe_enabled`` flag on ports (**dtantsur**)
