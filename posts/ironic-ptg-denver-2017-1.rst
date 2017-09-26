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

This part covers Pike recap and retrospective, status updates and CI work.

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

Deploy steps
^^^^^^^^^^^^

We agreed to continue this effort, even though the ansible deploy driver solves
some of its use cases. The crucial point is how to pass the requested deploy
steps parameters from a user to ironic. For a non-standalone case it means
passing them through nova.

In a discussion in the nova room we converged to an idea of introducing new
CRUD API for *deploy templates* (the exact name to be defined) on the ironic
side. Each such template will have a unique name and will correspond to a
*deploy step* and a set of arguments for it. On the nova side, a *trait* can
be requested with a name matching (in some sense) the name of a deploy
template. It will be passed to ironic, and ironic will apply the action,
specified in the template, during deployment.

The exact implementation and API will be defined in a spec, **johnthetubaguy**
is writing it.

Networking features
^^^^^^^^^^^^^^^^^^^

Routed network support is close to completion, we need to finish a patch for
networking-baremetal.

The neutron event processing work is on a spec stage, but does not look
controversial for now.

We also have patches up for deprecating DHCP providers and for making our DHCP
code less dnsmasq-specific.

ironic-inspector HA
^^^^^^^^^^^^^^^^^^^

Preparation work is under way. We are making our PXE boot management
pluggable, with a new implementation on review that manages a *dnsmasq*
process directly, instead of changing *iptables*.

We seem to agree that rolling upgrades are not a priority for
ironic-inspector, as it's never hit via end users either directly or through
another service. It's a purely admin-only API, and admins can plan for a
potential outage.

There is a proposal to support ironic boot interfaces instead of a home-grown
implementation for boot management. The discussion of it launched a more
global discussion about ironic-inspector future, that continued the next day.

Just Do It
^^^^^^^^^^

The following former priorities have all or the most of patches up for review,
and just require some attention:

* Node tags

* IPA API versioning

* Rescue mode

* Supported power states API

* E-Tags in API

.. _public etherpads: https://etherpad.openstack.org/p/ironic-queens-ptg
.. _Removing the classic drivers: http://specs.openstack.org/openstack/ironic-specs/specs/approved/classic-drivers-future.html

OpenStack goals status
----------------------

We have not completed either of the two goals for the Pike cycle, and now we
have two more goals to complete. All four goals are relatively close to
completion.

Python 3
~~~~~~~~

We have a non-voting integration job on ironic and a voting functional test
job on ironic-inspector. The missing steps are:

* make the python 3 job voting on ironic
* implement a job with IPA running on python 3 (blocked by pyudev weirdness)
* create an integration job with python 3 for ironic-inspector (mostly blocked
  by swift, will have reduced coverage; an alternative is to try RadosGW)

Switching to uWSGI
~~~~~~~~~~~~~~~~~~

Ironic standalone tests are running with mod_wsgi and voting, we only need to
switch to uWSGI.

For ironic-inspector it's much more complicated: it does not have a separate
API service for now at all. It's unclear if we'll able to just launch the
current service as it is behind a WSGI container, as we actively use green
threads. We have to probably wait until the HA work is done.

Splitting away the tempest plugin
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We have a script to extract git history for a sub-tree. We need to create a
separate git repository somewhere, so that we do not submit 60-80 related
patches to zuul. Then this repository will be imported by the infra team, and
we'll proceed with the migration.

On the previous (ATL) PTG we decided to have ironic and ironic-inspector
plugins co-located. This will be less confusing for external users, as many of
them to not understand the difference clearly, but it will also complicate the
migration.

We will need to plan the actual migration in advance, and freeze the version
in-tree for some time.

Policy in the code
~~~~~~~~~~~~~~~~~~

The ironic part is essentially done, we just need to change the way we
document policy: https://review.openstack.org/#/c/502519/.

No policy support exists in ironic-inspector, and it's unclear if this goal
assumes adding it. There is a desire to do so anyway.

Future development of our CI
----------------------------

Standalone tests
~~~~~~~~~~~~~~~~

We have standalone tests voting, but we're not fully using their potential.
In the end, we want to reduce the number of **non**-standalone jobs to:

#. a whole disk image job,
#. a partition images job,
#. a boot-from-volume job,
#. a multi-node job with advanced networking (can be merged with one of the
   first two),
#. two grenade jobs: full and partial.

The following tests can likely be part of the standalone job:

* tests for all combinations of disk types and deploy methods,
* tests covering all community-supported drivers (snmp, redfish),
* tests on different boot options (local vs network boot),
* tests on root device hints (we plan to cover serial number, wwn and size
  with operators),
* node adoption.

Take over testing
~~~~~~~~~~~~~~~~~

The take over feature is very important for our HA model, but is completely
untested. We discussed the two most important test cases:

#. conductor failure during deployment with node in ``deploy wait``,
#. conductor failure for an active node using network boot.

We discussed two ways of implementing the test: using a multi-node job with two
conductors or using only one conductor. The latter requires a trick: after
killing the conductor, change its host name, so that it looks like a new
conductor. In either case, we can combine both tests into one run:

#. start deploying two nodes with netboot:

   #. ``driver=manual-management deploy_interface=iscsi``,
   #. ``driver=manual-management deploy_interface=direct``,

   The remaining steps will be repeated for both nodes.

#. Wait for nodes ``provision_state`` becomes ``deploy wait``.
#. Kill the conductor.
#. Manually clean up the files from the TFTP and HTTP directories and the
   master image cache.
#. Change the conductor host name in ``ironic.conf``.
#. Wait for directories to be populated again.

   .. note:: We should aim to remove this step eventually.

#. ``virsh start`` the nodes to continue their deployment.
#. Wait for nodes to become ``active``.

Here is where the second test starts:

#. Repeat steps 3 - 6.
#. ``virsh reboot`` the nodes.
#. Check SSH connection to the rebooted instances.

In the future, we would also like to have negative tests on failed take over
for nodes in ``deploying``. We should also have similar tests for cleaning.

Pike retrospective
------------------

We've had a short retrospective. Positive items:

* Virtual midcycle
* Weekly bug liaison (action: start doing it again),
* Weekly priorities
* Landed some big features
* Acknowledge that vendors need more attention
* Did not drive our PTL away :)

Not so positive:

* Loss of people
* Gate breakages (action: better hand off of current mitigation actions
  between timezones, report on IRC and the whiteboard what you've done and
  what's left)
* Took too many priorities (action: take less, make the community understand
  that priorities != full backlog)
* Still not enough attention to vendors (action: accept one patch per vendor
  as part of weekly priorities; the same for subteams)
* Soft feature freeze
* Need more folks reviewing (action: **jlvillal** considers picking up the
  weekly review call)
* Releasing and cutting stable/pike was a mess (discussed in `Release cycle`_)
* No alignment between OpenStack releases and vendor hardware releases.

Release cycle
-------------

We had really hard time releasing Pike. Grenade was branched before us,
essentially messing up our upgrade testing. We had to cut out stable/pike at a
random point, and then backport quite a few features, after repairing the CI.

When discussing that, we noted that we committed to releasing often and early,
but we'd never done it, at least not for ironic itself. Having regular
releases can help us avoiding getting overloaded in the end of the cycle.
We've decided:

* Keep master as close to a releasable state as possible, including not
  exposing incomplete features to users and keeping release notes polished.
* Release regularly, especially when we feel that something is ready to got
  out. Let us aim for releasing roughly once a month.
* Let us cut stable/pike at the same time as the other projects. We will use
  the last released version as a basis for it.
* We are going back to feature freeze at the same time as the other projects,
  two weeks before the branching at milestone 3. This will allow us to finish
  anything requiring finishing, particularly rolling upgrade preparation,
  documentation and release notes.
