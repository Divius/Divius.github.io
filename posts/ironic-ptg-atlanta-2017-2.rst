.. title: Atlanta PTG Summary: Ironic (part 2)
.. slug: ironic-ptg-atlanta-2017-2
.. date: 2017-03-01 15:30 UTC+01:00
.. tags: software, openstack
.. category: 
.. link: 
.. description: 
.. type: text

This is an extract from my personal notes and public etherpads from the
OpenStack PTG 2017 in Atlanta. A lot of text ahead!

`The previous part <../posts/ironic-ptg-atlanta-2017-1.html>`_,
`the next part <../posts/ironic-ptg-atlanta-2017-3.html>`_.

.. TEASER_END: Read more

CI and testing
--------------

Etherpad: https://etherpad.openstack.org/p/ironic-pike-ptg-ci-testing

Missing CI coverage
~~~~~~~~~~~~~~~~~~~

UEFI
    Cirros finally released a stable version with UEFI support built in.
    A non-voting job is running with partition images, should be made voting
    soon. A test with whole disk images will be introduced as part of
    `standalone tests <https://review.openstack.org/#/c/423556/>`_.
Local bootloader
    Requires small enough instance images with Grub2 present (Cirros does not
    have it). We agreed to create a new repository with scripts to build
    suitable images. Potentially can be shared with other teams (e.g. Neutron).

    Actions: **lucasagomes** and/or **vsaienko** to look into it.
Adopt state
    Tests have been up for some time, but have ordering issues with nova-based
    tests. Suggesting **TheJulia** to move them to `standalone tests`_.
Root device hints
    Not covered by any CI. Will need modifying how we create virtual machines.
    First step is to get size-based hints work. Check two cases: with size
    strictly equal and greater than requested.

    Actions: **dtantsur** to look into it.
Capabilities-based scheduling
    This may actually go to Nova gate, not ours. Still, it relies on some code
    in our driver, so we'd better cover it to ensure that the placement API
    changes don't break it.

    Actions: **vsaienko** to look into it.
Port groups
    The same image problem as with local boot - the same action item to create
    a repository with build scripts to build our images.
VLAN-aware instances
    The same image problem + requires `reworking our network simulation code
    <https://review.openstack.org/#/c/392959/>`_.
Conductor take over and hash ring
    Requires a separate multi-node job.

    Action: **vsaienko** to investigate.

DIB-based IPA image
^^^^^^^^^^^^^^^^^^^

Currently the ``ironic-agent`` element to build such image is in the DIB
repository outside of our control. If we want to properly support it, we need
to gate on its changes, and to gate IPA changes on its job. Some time ago we
had a tentative agreement to move the element to our tree.

It was blocked by the fact that DIB rarely or never removes elements, and does
not have a way to properly de-duplicate elements with the same name.

An obvious solution we are going to propose is to take this element in IPA
tree under a different name (``ironic-python-agent``?). The old element will
get deprecated and only critical fixes will be accepted for it.

Action
    **dtantsur** to (re)start this discussion with the TripleO and DIB teams.

API microversions testing
^^^^^^^^^^^^^^^^^^^^^^^^^

We are not sure we have tests covering all microversions. We seem to have API
tests using ``fake`` driver that cover at least some of them. We should start
paying more attention to this part of our testing.

Actions
    **dtantsur** to check if these tests are up-to-date and split them to a
    separate CI job.
    **pas-ha** to write API tests for internal API (i.e. lookup/heartbeat).

Global OpenStack goals
~~~~~~~~~~~~~~~~~~~~~~

Splitting away tempest plugins
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

It did not end up a goal for Pike, and there are still some concerns in the
community. Still, as we already apply ugly hacks in our jobs to use the
tempest plugin from master, we agreed to proceed with the split.

To simplify both maintenance and consuming our tests, we agreed to merge
ironic and ironic-inspector plugins. The introspection tests will or will
not run based on ironic-inspector presence.

We propose having a merged core team (i.e. ironic-inspector-core which
already includes ironic-core) for this repository. We trust people who
only have core rights on ironic-inspector to not approve things they're
not authorized to approve.

Python 3 support
^^^^^^^^^^^^^^^^

We've been running Python 3 unit tests for quite some time. Additionally,
ironic-inspector runs a non-voting Python 3 functional test. Ironic has an
experimental job which fails, apparently, because of swift. We can start with
switching this job to the ``pxe_ipmitool`` driver (not requiring swift).
Inspector does not have a Python 3 integration tests job proposed yet.

Actions
    **JayF** and **hurricanerix** will drive this work in both ironic and
    ironic-inspector.

    **lucasagomes** to check pyghmi and virtualbmc compatibility.

    **krtaylor** and/or **mjturek** to check MoltenIron.

We agreed that Bifrost is out of scope for this task. Its Python 3
compatibility mostly depends on one of Ansible anyway. Similarly, for the UI
we need horizon to be fully Python 3 compatible first.

Important decisions
    We recommend vendors to make their libraries compatible with Python 3.
    It may become a strict requirement in one of the coming releases.

API behind WSGI container
^^^^^^^^^^^^^^^^^^^^^^^^^

This seems quite straightforward. The work has started to switch ironic CI to
WSGI already. For ironic-inspector it's going to be done as part of the HA
work.
