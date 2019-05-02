.. title: Ironic at OpenInfra Summit and PTG
.. slug: ironic-denver-2019
.. date: 2019-05-02 19:00:36 UTC+02:00
.. tags: openstack, software
.. category: 
.. link: 
.. description: 
.. type: text

This is a summary of bare metal discussions at the OpenInfra Summit & PTG in
Denver.

.. TEASER_END: Read more

Metal3
======

The `Metal3`_ project got some spotlight during the keynotes. A (successful!)
`live demo`_ was done that demonstrated using Ironic through Kubernetes API to
drive provisioning of bare metal nodes.

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

.. _Metal3: http://metal3.io
.. _live demo: https://www.openstack.org/videos/summits/denver-2019/openstack-ironic-and-bare-metal-infrastructure-all-abstractions-start-somewhere
.. _standalone roadmap session: https://etherpad.openstack.org/p/DEN-train-next-steps-for-standalone-ironic
.. _networking-ansible: https://opendev.org/x/networking-ansible
.. _API multi-tenancy session: https://etherpad.openstack.org/p/DEN-train-ironic-multi-tenancy
.. _Scientific SIG discussions: https://etherpad.openstack.org/p/scientific-sig-ptg-train
.. _Ramdisk deploy: https://docs.openstack.org/ironic/latest/admin/interfaces/deploy.html#ramdisk-deploy
.. _fast-track deploy: https://storyboard.openstack.org/#!/story/2004965
