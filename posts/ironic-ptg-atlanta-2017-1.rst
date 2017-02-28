.. title: Atlanta PTG Summary: Ironic (part 1)
.. slug: ironic-ptg-atlanta-2017-1
.. date: 2017-02-28 15:15 UTC+01:00
.. tags: software, openstack
.. category: 
.. link: 
.. description: 
.. type: text

Atlanta PTG Summary: Ironic (part 1)
====================================

This is an extract from my personal notes and public etherpads from the
OpenStack PTG 2017 in Atlanta. A lot of text ahead!

.. TEASER_END: Read more

Ongoing work and status updates
-------------------------------

Etherpad: https://etherpad.openstack.org/p/ironic-pike-ptg-ongoing-work.

We spent the first half of Wednesday discussing this. There was a lot of
incomplete work left from Ocata, and some major ongoing work that we did not
even plan to finish in Ocata.

Boot-from-volume
~~~~~~~~~~~~~~~~

Got some progress, most of the Ironic patches are up. Desperately needs review
and testing, though. The Nova part is also lagging behind, and should be
brought to the Nova team attention.

**Actions**
    **mgoddard** and **dtantsur** volunteered to help with testing, while
    **mjturek**, **hsiina** and **crushil** volunteered to do some coding.
**Goals for Pike**
    finish the first (iSCSI using iPXE) case and the Nova part.

Networking
~~~~~~~~~~

A lot of progress here during Ocata, completed bonding and attach/detach API.

VLAN-aware instances should work. However, it requires an expensive ToR switch,
supporting VLAN/VLAN and VLAN/VXLAN rewriting, and, of course ML2 plugin
support. Also, reusing an existing segmentation ID requires more work: we have
no current way to put the right ID in the configdrive.

**Actions**
    **vsaienko**, **armando** and **kevinbenton** are looking into the Neutron
    part of the configdrive problem.

Routed networks support require Ironic to be aware of which physical network(s)
each node is connected to.

**Goals for Pike**
    * model physical networks on Ironic ports,
    * update VIF attach logic to no longer attach things to wrong physnets.

We discussed introducing notifications from Neutron to Ironic about events
of interest for us. We are going to use the same model as between Neutron and
Nova: create a Neutron plugin that filters out interesting events and posts
to a new Ironic API endpoint.

**Goals for Pike**
    have this notification system in place.

Finally, we agreed that we need to work on a reference architecture document,
describing the best practices of deploying Ironic, especially around
multi-tenant networking setup.

**Actions**
    **jroll** to kickstart this document, **JayF** and **mariojv** to help.

Rolling upgrades
~~~~~~~~~~~~~~~~

Missed Ocata by a small margin. The code is up and needs reviewing. The CI
is waiting for the multinode job to start working (should be close as well).

**Goals for Pike**
    rolling upgrade Ocata -> Pike.

Driver composition reform
~~~~~~~~~~~~~~~~~~~~~~~~~

Most of the code landed in Ocata already. Some client changes landed in Pike,
some are still on review. As we released Ocata with the driver composition
changes being experimental, we are not ready to deprecate old-style drivers in
Pike. Documentation is also still lacking.

**Goals for Pike**
    * make new-style dynamic drivers the recommend way of writing and using
      drivers,
    * fill in missing documentation,
    * *recommend* vendors to have hardware types for their hardware, as well
      as 3rdparty CI support for it.
**Important decisions**
    * no new classic drivers are accepted in-tree (please check when accepting
      specifications),
    * no new interfaces additions for classic drivers(``volume_interface`` is
      the last accepted from them),
    * remove the SSH drivers by Pike final (probably around M3).

Ironic Inspector HA
~~~~~~~~~~~~~~~~~~~

Preliminary work (switch to a real state machine) done in Ocata. Splitting the
service into API and conductor/engine parts correlates with the WSGI
cross-project goal.

We also had a deeper discussion about ironic-inspector architecture earlier
that week, where we were `looking
<https://etherpad.openstack.org/p/ironic-pike-ptg-inspector-arch>`_ into
potential future work to make ironic-inspector both HA and multi-tenancy
friendly. It was suggested to split *discovery* process (simple process to
detect MACs and/or power credentials) and *inspection* process (full process
when a MAC is known).

**Goals for Pike**
    * switch locking to ``tooz`` (with Redis probably being the default
      backend for now),
    * split away API process with WSGI support,
    * leader election using ``tooz`` for periodic tasks,
    * stop messing with ``iptables`` and start directly managing ``dnsmasq``
      instead (similarly to how Neutron does it),
    * try using ``dnsmasq`` in active/active configuration with
      non-intersecting IP addresses pools from the same subnet.
**Actions**
    also **sambetts** will write a spec on a potential workflow split.

Ironic UI
~~~~~~~~~

The project got some important features implemented, and an RDO package
emerged during Ocata. Still, it desperately needs volunteers for coding and
testing. A `spreadsheet
<https://docs.google.com/spreadsheets/d/1petifqVxOT70H2Krz7igV2m9YqgXaAiCHR8CXgoi9a0/edit?usp=sharing>`_
captures the current (as of beginning of Pike) status of features.

**Actions**
    **dtantsur**, **davidlenwell**, **bradjones** and **crushil** agreed to
    dedicate some time to the UI.

Rescue
~~~~~~

Most of the patches are up, the feature is tested with the CoreOS-based
ramdisk for now. Still, the ramdisk side poses a problem: while using DHCP is
easy, static network configuration seems not. It's especially problematic in
CoreOS. Might be much easier in the DIB-based ramdisk, but we don't support it
offcially in the Ironic community.

RedFish driver
~~~~~~~~~~~~~~

We want to get a driver supporting redfish soon. There was some critics raised
around the currently proposed python-redfish library. As an alternative,
`a new library <https://github.com/openstack/sushy>`_ was written. Is it
lightweight, covered by unit tests and only contain what Ironic needs.
We agreed to start our driver implementation with it, and switch to the
python-redfish library when/if it is ready to be consumed by us.

We postponed discussing advanced features like nodes composition till after
we get the basic driver in.

Small status updates
~~~~~~~~~~~~~~~~~~~~

* Of the API evolution initiative, only E-Tag work got some progress. The spec
  needs reviewing now.

* Node tags work needs review and is close to landing. We decided to discuss
  port tags as part of a separate RFE, if anybody is interested.

* IPA API versioning also needs reviews, there are several moderately
  contentions points about it. It was suggested that we only support one
  direction of IPA/ironic upgrades to simplify testing. We'll probably only
  support old IPA with new ironic, which is already tested by our grenade job.
