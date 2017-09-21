.. title: Denver PTG Summary: Ironic (part 1)
.. slug: ironic-ptg-denver-2017-1
.. date: 2017-09-21 15:22:52 UTC+02:00
.. tags: software, openstack
.. category: 
.. link: 
.. description: 
.. type: text

Denver PTG Summary: Ironic (part 1)
===================================

This is an extract from my personal notes and `public etherpads`_ from the
OpenStack PTG 2017 in Denver. A lot of text ahead!

.. TEASER_END: Read more

Status of Pike priorities
-------------------------

In the Pike cycle, we had 22 priority items. Quite a few planned priorities
did land completely, despite the well-known staffing problems.

Finished
~~~~~~~~

Booting from cinder volumes
^^^^^^^^^^^^^^^^^^^^^^^^^^^

This includes the iRMC implementation, but excludes the iLO one. There is
also a nova patch for updating IP addresses for volume connectors on review:
https://review.openstack.org/#/c/468353/.

Next, we need to update cinder to support FCoE - then we'll be able to
support it in the generic PXE boot interface. Finally, there is some interest
in implementing out-of-band BFV for UCS drivers too.

Rolling (online) upgrades between releases
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

We've found a bug that was backported to stable/pike soon after the release
and now awaits a point release. We also need developer documentation and
some post-Pike clean ups.

We also discussed fast-forward upgrades. We may need an explicit migration
for VIFs from port.extra to port.internal_info, **rloo** will track this.
Overall, we need to always make our migrations explicit and runnable without
the services running.

The driver composition reform
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Finished, with hardware types created for all supported hardware. `Removing
the classic drivers`_ is planned for Rocky with deprecation in Queens.

Standalone jobs (jobs without nova)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

These are present and voting, but we're not using their potential. The
discussion is summarized below in `Future development of our CI`_.

Feature parity between two CLI implementations
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``openstack baremetal`` CLI is now complete and preferred, with the
deprecation of the ``ironic`` CLI expected in Queens.

We would like OSC to have less dependencies though. There were talks about
having a standalone ``openstack`` command without dependencies on other
clients, only on ``keystoneauth1``. **rloo** will follow up here.

**TheJulia** will check if there are any implications from the
interoperability team point of view.

Redfish hardware type
^^^^^^^^^^^^^^^^^^^^^

The ``redfish`` hardware type now provides all the basic stuff we need, i.e.
power and boot device management. There is an ongoing effort to implement
inspection. It is unclear whether more features can be implemented in a
vendor-agnostic fashion; **rpioso** is looking into Dell, while **crushil**
is looking into Lenovo.

Other
^^^^^

Also finished are:

* Post-deploy VIF attach/detach.

* Physical network awareness.

Not finished
~~~~~~~~~~~~

OSC default API version
^^^^^^^^^^^^^^^^^^^^^^^

We now issue a warning of no explicit version is provided to the CLI.
The next step will be to change the version to latest, but our current
definition of latest does not fit this goal really well. We use the latest
version known to the client, which will prevent it from working out-of-box
with older clouds. Instead, we need to finally implement API version
negotiation in ironicclient, and negotiate the latest version.

Reference architectures guide
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

There is one patch that lays out considerations that are going to be shared
between all proposed architectures. The use cases we would like to cover:

* Admin-only provisioner (standalone architectures)

  * Small fleet and/or rare provisions.

    Here a non-HA architecture may be acceptable, and a *noop* or *flat*
    networking can be used.

  * Large fleet or frequent provisions.

    Here we will recommend HA and *neutron* networking. *Noop* networking is
    also acceptable.

* Bare metal cloud for end users (with nova)

  * Smaller single-site cloud.

    Non-HA architecture and *flat* or *noop* networking is acceptable.
    Ironic conductors can live on OpenStack controller nodes.

  * Large single-site cloud.

    HA is required, and it is recommended to split ironic conductors with
    their TFTP/HTTP servers to separate machines. *Neutron* networking
    should be used, and thus compatible switches will be required, as well
    as their ML2 mechanism drivers.

    It is preferred to use virtual media instead of PXE/iPXE for deployment
    and cleaning, if supported by hardware. Otherwise, especially large
    clouds may consider splitting away TFTP servers.

  * Large multi-site cloud.

    The same as a single-site cloud plus using Cells v2.

.. _public etherpads: https://etherpad.openstack.org/p/ironic-queens-ptg
.. _Removing the classic drivers: http://specs.openstack.org/openstack/ironic-specs/specs/approved/classic-drivers-future.html

Future development of our CI
----------------------------
