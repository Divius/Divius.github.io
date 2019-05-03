.. title: Ironic at OpenInfra Summit and PTG
.. slug: ironic-denver-2019
.. date: 2019-05-02 19:00:36 UTC+02:00
.. tags: openstack, software
.. category: 
.. link: 
.. description: 
.. type: text

This is a summary of bare metal discussions at the OpenInfra Summit & PTG 2019
in Denver.

.. TEASER_END: Read more

Keynotes
========

The `Metal3`_ project got some spotlight during the keynotes. A (successful!)
`live demo`_ was done that demonstrated using Ironic through Kubernetes API to
drive provisioning of bare metal nodes.

The official `bare metal program`_ was announced to promote managing bare metal
infrastructure via OpenStack.

Forum: standalone Ironic
========================

On Monday we had two sessions dedicated to the future development of standalone
Ironic (without Nova or without any other OpenStack services).

During the `standalone roadmap session`_ the audience identified two potential
domains where we could provide simple alternatives to depending on OpenStack
services:

* Alternative authentication. It was mentioned, however, that Keystone is a
  relatively easy service to install and operate, so adding this to Ironic
  may not be worth the effort.

* Multi-tenant networking without Neutron. We could use networking-ansible_
  directly, since they are planning on providing a Python API independent of
  their ML2 implementation.

Next, firmware update support has been a recurring topic (also in hallway
conversations and also in non-standalone context). Related to that, a driver
feature matrix documentation was requested, so that such driver-specific
features are easier to discover.

Then we had a separate `API multi-tenancy session`_. Three topic were covered:

* Wiring in the existing ``owner`` field for access control.

  The idea is to allow operations for non-administrator users only to nodes
  with ``owner`` equal to their project (aka tenant) ID. In the non-keystone
  context this field would stay free-form. We did not agree whether we need an
  option to enable this feature.

  An interesting use case was mentioned: assign a non-admin user to Nova, to
  allocate it only a part of the bare metal pool, instead of all nodes.

  We did not reach a consensus on whether we should use a schema with the
  ``owner`` field, e.g. ``keystone://{project ID}`` would represent a Keystone
  project ID.

* Adding a new field (probably ``deployed_by``) to track a user that requested
  a deploy for auditing purposes.

  We agreed that the ``owner`` field should not be used for this purpose, and
  overall it should not be changed automatically.

* Adding some notion of *node leased to*, probably via a new field.

  This proposal was not well defined during the session, but we probably would
  allow some subset of API to leasers using the policy mechanism. It became
  apparent, that implementing a separate *deployment API endpoint* is required
  to make such policy possible.

Creating the deployment API was identified as a potential immediate action
item. Wiring the ``owner`` field can also be done in the Train cycle, if we
find volunteers to push it forward.

PTG: scientific SIG
===================

The PTG started for me with the `Scientific SIG discussions`_ of desired
features and fixes in Ironic.

The hottest topic was reducing the deployment time by reducing the number of
reboots that are done during the whole provisioning process. `Ramdisk deploy`_
was identified as a very promising feature to solve this, as well as enable
booting from remote volumes not supported directly by Ironic and/or Cinder.
A few SIG members committed to testing it as soon as possible.

Two related ideas were proposed for later brainstorming:

* Keeping some proportion of nodes always on and with IPA booted. This is
  basing directly on the `fast-track deploy`_ work completed in the Stein
  cycle.

* Allow using *kexec* to instantly switch into a freshly deployed operating
  system.

Combined together, these features can allow zero-reboot deployments.

PTG: Ironic
===========

Community sustainability
------------------------

We seem to have a disbalance in reviews, with very few people handling the
majority of reviews, and some of them are close to burning out.

* The first thing we discussed is simplifying the specs process. We considered a
  single +2 approval for specs and/or documentation. Approving documentation
  cannot break anyone, and follow-ups are easy, so it seems a good idea.

* Fascilitating deprecated feature removals can help clean up the code, and it
  can often be done by new contributors. We would like to maintain a list of
  what can be removed when, so that we don't forget it.

* We would also like to switch to single +2 for stable backports.

We felt that we're adding cores at a good pace, Julia had been mentoring people
that wanted it. We would like people to volunteer, then we can mentor them into
core status.

However, we were not so sure we wanted to increase the stable core team. This
team is supposed to be a small number of people that know quite a few small
details of the stable policy (e.g. requirements changes). We thought we should
better switch to single +2 approval for the existing team.

Then we discussed moving away from WSME, which is barely maintained by a team
of not really interested individuals. The proposal was to follow the example of
Keystone and just move to Flask. We can use ironic-inspector as an example, and
probably migrate part by part. JSON schema could replace WSME objects,
similarly to how Nova does it.

Standalone roadmap
------------------

We started with a recap of items from `Forum: standalone Ironic`_.

While discussing creating a driver matrix, we realized that we could keep
driver capabilities in the source code (similar to existing iSCSI boot) and
generate the documentation from it. Then we could go as far as exposing this
information in the API.

During the multi-tenancy discussion, the idea of owner and leasee fields was
well received. Julia volunteered to write a specification for that. We
clarified the following access control policies implemented by default:

* A user can list or show nodes if they are an administrator, an owner of a
  node or a leasee of this node.
* A user can deploy or undeploy a node (through the future deployment API) if
  they are an administrator, an owner of this node or a leasee of this node.
* A user can update a node or any of its resources if they are an administrator
  or an owner of this node. A leasee of a node can **not** update it.

The discussion of recording the user that did a deployment turned into
discussing introducing a searchable log of changes to node power and provision
states.

Deploy steps continued
----------------------

This session was dedicated to making the deploy templates framework more usable
in practice.

* We agreed that we need to implement support for in-band deploy steps (other
  than the built-in ``deploy.deploy`` step). We probably need to start IPA
  before proceeding with the steps, similarly to how it is done with cleaning.

* We agreed to proceed with splitting the built-in core step, making it a
  regular deploy step, as well as removing the compatibility shim for drivers
  that do not support deploy steps. We will probably separate writing an image
  to disk, writing a configdrive and creating a bootloader.

  The latter could be overridden to provide custom kernel parameters.

* To handle potential differences between deploy steps in different hardware
  types, we discussed the possibility of optionally including a hardware type
  or interface name in a clean step. Such steps will only be run for nodes with
  matching hardware type or interface.

Mark and Ruby volunteered to write a new spec on these topics.

Day 2 operational workflow
--------------------------

For deployments with extensive external monitoring, we need a way to reflect in
ironic the state when a deployed node looks healthy from our side but is
detected as failed by the monitoring.

It seems that we could introduce a new state transition from ``active`` to
something like ``failed`` or ``quarantened``, where a node is still deployed,
but explicitly marked as at fault by an operator. On unprovisioning, this node
would not become ``available`` automatically. We also considered the
possibility of using a flag instead of a new state, although the operators in
the room were more in favour of using a state. We largely agreed that the
already overloaded ``maintenance`` flag should not be used for this.

On the Nova side we would probably use the ``error`` state to reflect nodes in
the new state.

DHCP-less deploy
----------------

We discussed options to avoid relying on DHCP for deploying.

* An existing specification proposes attaching IP information to virtual media.
  The initial contributors had become inactive, so we decided to help this work
  to go through.

* As an alternative to that, we discussed using IPv6 SLAAC with multicast DNS
  (routed across WAN for Edge cases). A couple of folks on the room volunteered
  to help with testing. We need to fix python-zeroconf_ to support IPv6.

Nova room
---------

In a cross-project discussion with the Nova team we went through a few topics:

* We discussed whether Nova should use new Ironic API to build configdrives.
  Since Ironic is not the only driver building configdrives, we agreed that it
  probably doesn't make much sense to change that.

* We did not come to a conclusion on deprecating capabilities. We agreed that
  Ironic has to provide alternatives for ``boot_option`` and ``boot_mode``
  capabilities first. These will probably become deploy steps or built-in
  traits.

* We agreed that we should switch Nova to using *openstacksdk* instead of
  *ironicclient* to access Ironic. This work is already in progress.

Faster deploy
-------------

We followed up to `PTG: scientific SIG`_ with potential action items on
speeding up the deployment process by reducing the number of reboots. We
discussed an ability to keep all or some nodes powered on and heartbeating in
the ``available`` state:

* Add an option to keep the ramdisk running after cleaning.

  * For this to work with multi-tenant networking we'll need an IPA command to
    reset networking.

* Add a provisioning verb going from ``available`` to ``available`` booting the
  node into IPA.

* Make sure that pre-booted nodes are prioritized for scheduling. We will
  probably dynamically add a special trait. Then we'll have to update both
  Nova/Placement and the allocation API to support preferred (optional) traits.

We also agreed that we could provide an option to *kexec* instead of rebooting
as an advanced deploy step for operators that really know their hardware.
Multi-tenant networking can be tricky in this case, since there is no safe
point to switch from deployment to tenant network. We will probably take a best
effort approach: command IPA to shutdown all its functionality and schedule a
*kexec* after some time. After that, switch to tenant networks. This is not
entirely secure, but will probably fit the operators (HPC) who requests it.

PTG: TripleO
============

We discussed possibility of removing Nova from the TripleO undercloud and
moving bare metal provisioning from under control of Heat. The plan from the
`nova-less-deploy specification`_, as well as the current state
of the implementation, were presented.

The current concerns are:

* upgrades from a Nova based deployment (probably just wipe the Nova
  database),
* losing user experience of ``nova list`` (largely compensated by
  ``metalsmith list``),
* tracking IP addresses for networks other than *ctlplane* (solved the same
  way as for deployed servers).

The next action item is to create a CI job based on the already merged code and
verify a few assumptions made above.

Side and hallway discussions
============================

* We discussed a request from the Edge WG to have a special "failure" provision
  state that can be detected and entered by a request from a third party
  monitoring tooling (as opposed to from within Ironic itself). It's unclear if
  the existing *rescue* feature can fill this gap.

.. _Metal3: http://metal3.io
.. _live demo: https://www.openstack.org/videos/summits/denver-2019/openstack-ironic-and-bare-metal-infrastructure-all-abstractions-start-somewhere
.. _bare metal program: https://www.openstack.org/bare-metal/
.. _standalone roadmap session: https://etherpad.openstack.org/p/DEN-train-next-steps-for-standalone-ironic
.. _networking-ansible: https://opendev.org/x/networking-ansible
.. _API multi-tenancy session: https://etherpad.openstack.org/p/DEN-train-ironic-multi-tenancy
.. _Scientific SIG discussions: https://etherpad.openstack.org/p/scientific-sig-ptg-train
.. _Ramdisk deploy: https://docs.openstack.org/ironic/latest/admin/interfaces/deploy.html#ramdisk-deploy
.. _fast-track deploy: https://storyboard.openstack.org/#!/story/2004965
.. _python-zeroconf: https://github.com/jstasiak/python-zeroconf
.. _nova-less-deploy specification: http://specs.openstack.org/openstack/tripleo-specs/specs/stein/nova-less-deploy.html
