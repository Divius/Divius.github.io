.. title: Atlanta PTG Summary: Ironic (part 3)
.. slug: ironic-ptg-atlanta-2017-3
.. date: 2017-03-06 17:00 UTC+01:00
.. tags: software, openstack
.. category: 
.. link: 
.. description: 
.. type: text

This is an extract from my personal notes and public etherpads from the
OpenStack PTG 2017 in Atlanta. A lot of text ahead!

`The previous part <../posts/ironic-ptg-atlanta-2017-2.html>`_,
`the next part <../posts/ironic-ptg-atlanta-2017-4.html>`_.

.. TEASER_END: Read more

Operations
----------

Etherpad: https://etherpad.openstack.org/p/ironic-pike-ptg-operations

OSC plugin and API versioning
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Currently we default the OSC plugin (and old client too) to a really old API
version. We agreed that this situation is not desired, and that we should take
the same approach as Nova and default to the latest version. We are planning
to announce the change this cycle, both via the ML and via a warning issues
when no versions are specified.

Next, in the Queens cycle, we will have to make the change, bearing in mind
that OSC does not support values like ``latest`` for API versions. So the plan
is as follows:

* make the default ``--os-baremetal-api-version=1`` in
  https://github.com/openstack/python-ironicclient/blob/f242c6af3b295051019aeabb4ec7cf82eb085874/ironicclient/osc/plugin.py#L67

* when instantiating the ironic client in the OSC plugin, replace '1' with
  'latest':
  https://github.com/openstack/python-ironicclient/blob/f242c6af3b295051019aeabb4ec7cf82eb085874/ironicclient/osc/plugin.py#L41

* when handling ``--os-baremetal-api-version=latest``, replace it with ``1``,
  so that it's later replaced with ``latest`` again:
  https://github.com/openstack/python-ironicclient/blob/f242c6af3b295051019aeabb4ec7cf82eb085874/ironicclient/osc/plugin.py#L85

As a side effect, that will make ``1`` equivalent to ``latest`` as well.

It was also suggested to have an new command, displaying both server supported
and client supported API versions.

Deprecating the standalone ironic CLI in favor of the OSC plugin
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We do not want to maintain two CLI in the long run. We agreed to start
thinking about deprecating the old ``ironic`` command. Main concerns:

* lack of feature parity,

* ugly way to work without authentication, for example::

    openstack baremetal --os-url http://ironic --os-token fake <COMMAND>

Plan for Pike
    * Ensure complete feature parity between two clients.
    * Only use ``openstack baremetal`` commands in the documentation.

The actual deprecation is planned for Queens.

RAID configuration enhancements
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A few suggestions were made:

* Support ordered list of logical disk definition. The first possible
  configuration is applied to the node. For example:

  * Top of list - RAID 10 but we don't have enough drives
  * Fallback to next preference in list - RAID 1 on a pair of available drives
  * Finally, JBOD or RAID 0 on only available drive

* Specify the number of instances for a logical disk definition to create.

* Specify backing physical disks by stating preference for the smallest, e.g.
  smallest like-sized pair or two smallest disks.

* Specify location of physical disks, e.g. first two or last two as perceived
  by the hardware, front/rear/internal location.

Actions
    **rpioso** will write RFE(s)

Smaller topics
~~~~~~~~~~~~~~

Non-aborteable clean steps stuck in ``clean wait`` state
    We discussed a potential ``force-abort`` functionality, but the only thing
    we agreed on is check that all current clean steps are marked as
    ``abortable`` if they really are.

Status of long-running cleaning operations
    There is a request to be able to get status of e.g. disk shredding (which
    may take hours). We found out that the current IPA API design essentially
    prevents running several commands in parallel. We agreed that we need IPA
    API versioning first, and that this work is not a huge priority right now.

OSC command for listing driver and RAID properties
    We cannot agree on the exact form of these two commands. The primary
    candidates discussed on the PTG were::

        openstack baremetal driver property list <DRIVER>
        openstack baremetal driver property show <DRIVER>

    We agreed to move this to the spec: https://review.openstack.org/439907.

Abandoning an active node
    I.e. an opposite to adopt. It's unclear how such operation would play with
    nova, maybe it's only useful for a standalone case.

Future Work
-----------

Etherpad: https://etherpad.openstack.org/p/ironic-pike-ptg-future-work.

Neutron event processing
~~~~~~~~~~~~~~~~~~~~~~~~

RFE: https://bugs.launchpad.net/ironic/+bug/1304673, spec:
https://review.openstack.org/343684.

We need to wait for certain events from neutron (like port bindings).
Currently we just wait some time, and hope it went well. We agreed to follow
the same pattern that nova does for neutron to nova notifications.
The neutron part is
https://github.com/openstack/neutron/blob/master/neutron/notifiers/nova.py.
We agreed with the Neutron team that notifier and the other ironic-specific
stuff for neutron would live in a separate repo under Baremetal governance.
Draft code is https://review.openstack.org/#/c/357780.

Splitting node.properties[capabilities] into a separate table
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is something we've planned on for long time. Currently, it's not possible
to update capabilities atomically, and the format is quite hard to work with:
``k1:v1,k2:v2``. We discussed going away from using word ``capability``. It's
already overused in the OpenStack world, and nova is switching to the notion
of "traits". It also looks like traits will be qualitative-only while, we have
proposals from quantitative capabilities (like ``gpu_count``).

It was proposed to model a typical CRUD API for traits in Ironic::

    GET /v1/nodes/<NODE>/traits
    POST  /v1/nodes/<NODE>/traits
    GET /v1/nodes/<NODE>/traits/<trait>
    DELETE /v1/nodes/<NODE>/traits/<trait>

In API versions before this addition, we would make
``properties/capabilities`` a transparent proxy to new tables.

It was noted that the database change can be done first, with API change
following it.

Actions
    **rloo** to propose two separate RFEs for database and API parts.

Avoid changing behavior based on properties[capabilities]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Currently our capabilities have a dual role. They serve both for scheduling
(to inform nova of what nodes can) and for making decisions based on flavor
(e.g. request UEFI boot). It is complicated by the fact that sometimes the
same capability (e.g. UEFI) can be of both types depending on a driver.
This is quite confusing for users, and may be incompatible with future changes
both in ironic and nova.

For things like boot option and (potentially) BIOS setting, we need to be able
to get requests from flavors and/or nova boot arguments without abusing
capabilities for it. Maybe similar to how NUMA support does it:
https://docs.openstack.org/admin-guide/compute-cpu-topologies.html.

For example::

    flavor.extra_specs[traits:has_ssd]=True

(tells the scheduler to find a node with SSD disk; does not change
behavior/config of node)

::

    flavor.extra_specs[configuration:use_uefi]=True

(configures the node to boot UEFI; has no impact on scheduling)

::

    flavor.extra_specs[traits:has_uefi]=True
    flavor.extra_specs[configuration:use_uefi]=True

(tells the scheduler to find a node supporting UEFI; if this support is
dynamic, configures the node to enable UEFI boot).

Actions
    **jroll** to start conversation with nova folks about how/if to have a
    replacement for this elsewhere.

    Stop accepting driver features relying on ``properties[capabilities]`` (as
    opposed to ``instance_info[capabilities]``).

Potential actions
    * Remove ``instance_info[capabilities]`` into
      ``instance_info[configuration]`` for clarity.
