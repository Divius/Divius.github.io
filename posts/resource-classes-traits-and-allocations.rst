.. title: Bare Metal Resource Classes, Traits and Allocations
.. slug: resource-classes-traits-and-allocations
.. date: 2019-04-03 15:57:05 UTC+02:00
.. tags: openstack, coding
.. category: 
.. link: 
.. description: 
.. type: text

This blog post introduces the recent features for scheduling bare metal nodes
with `OpenStack Bare Metal (Ironic)`_. It explains *resource classes* and
*traits* as applied to bare metal nodes and show-cases the new `Allocation
API`_, introduced in the 12.1.0 (Stein) release.

.. TEASER_END: Read more

.. contents:: Table of Contents

History of Ironic and Nova
--------------------------

Long time ago, when the trees were greener and Ironic was younger, OpenStack
Compute (aka Nova) tried to work with bare metal nodes the same way it worked
with virtual machines. Each node pretended to be a separate hypervisor and
added its CPU count, RAM size and disk size to the pool of resources, as any
other hypervisor would. This beautiful idea, however, suffered from two serious
issues:

#. A flavor could request only a part of exposed resources (e.g. 1G RAM out of
   4G available). The remaining resources would be seen as available, even
   though there weren't.
#. During the *automated cleaning* process the nodes were no longer occupied
   from Nova's point of view, but they were nonetheless not available yet.

Two hacks were introduced in the Nova code base as solutions:

#. Ironic required a special *host manager* that made sure that any instance
   consumes all resources of a node.
#. During cleaning the nodes returned zero resources.

The existence of these hacks broke the illusion that bare metal machines behave
the same way as virtual hypervisors. Furthermore, races were possible when the
number of free instances was very low (e.g. in case of TripleO_ it isn't
uncommon to deploy all available nodes).

Resource Classes
----------------

An obvious solution to both problems mentioned above is to stop treating bare
metal hypervisors as pools of CPU/RAM/disk and start treating them the way
they are - single instances of an indivisible resource. This is where *custom
resource classes* come into play. The Placement_ service defines resource
classes as types of resources that can be tracked, consumed and released. For
example, the conventional CPU/RAM/disk triad maps to resource classes called
``VCPU``, ``MEMORY_MB`` and ``DISK_GB``.

What about bare metal nodes? Starting with the Newton release of Ironic, nodes
have a ``resource_class`` field that serves exactly this purpose: to define a
*custom resource class* of a node. Since the transitional period ended in the
Rocky cycle, each node exposes one instance of its custom resource class and
nothing else.

For example, a node defined as

.. code-block:: console

    $ openstack baremetal node create --name large-01 --driver ipmi --resource-class baremetal-large

will expose (once made ``available``) one instance of custom resource class
called ``CUSTOM_BAREMETAL_LARGE``. It can be consumed by a flavor defined with
(see `baremetal flavor documentation`_ for details):

.. code-block:: console

    $ openstack flavor set --property resources:CUSTOM_BAREMETAL_LARGE=1 my-baremetal-flavor

What is a resource class for bare metal in the end? These are just
non-overlapping groups of the bare metal nodes. If it's not possible to split
your nodes into such groups, you may opt for using only one custom resource
class (TripleO_ uses ``baremetal`` by default) and schedule bare metal nodes
solely using Traits_.

Traits
------

*Trait* is another concept that came into bare metal world from Placement. Its
name is mostly self-explanatory: it is something that can be true or false
about a node. Think, *Does this node have an OpenCV-enabled GPU?* or *Does this
node have virtualization CPU extension?* A whole bunch of *standard traits* is
defined by the os-traits_ library, but you can also define custom ones by
prefixing them with ``CUSTOM_``.

Starting with the Queens release, traits can be added to bare metal nodes:

.. code-block:: console

    $ openstack baremetal node add trait large-01 HW_CPU_X86_VMX CUSTOM_OPENCV
    Added trait HW_CPU_X86_VMX
    Added trait CUSTOM_OPENCV

As you see, I'm associating two traits with the node: one is standard (coming
from os-traits_), the other is custom (invented by me). Now we can update our
flavor to request them:

.. code-block:: console

    $ openstack flavor set --property trait:HW_CPU_X86_VMX=required my-baremetal-flavor
    $ openstack flavor set --property trait:CUSTOM_OPENCV=required my-baremetal-flavor

Now this flavor will make the scheduler take nodes with the resource class
``baremetal-large`` (defined in the previous section) and then choose from only
those with our two traits defined.

Allocation API
--------------

The previous two sections have covered scheduling bare metal nodes with Nova
pretty well. But what about using Ironic standalone? Indeed, we have been
advertizing standalone Ironic as a viable solution for a long time, including
maintaining the Bifrost_ project as ones of the ways to install and use it.
However, we did not have any scheduling story for standalone Ironic - until the
Stein release.

In the Stein release (Ironic 12.1.0+ and python-ironicclient 2.7.0+) a new
concept of an *allocation* is introduced (again, borrowing a similar term from
Placement). An allocation is a request to find a bare metal node with
suitable resource class and traits and reserve it via the existing
``instance_uuid`` mechanism (making it compatible with Nova).

.. code-block:: console

    $ openstack baremetal allocation create --resource-class baremetal-large --wait
    +-----------------+--------------------------------------+
    | Field           | Value                                |
    +-----------------+--------------------------------------+
    | candidate_nodes | []                                   |
    | created_at      | 2019-04-03T12:18:26+00:00            |
    | extra           | {}                                   |
    | last_error      | None                                 |
    | name            | None                                 |
    | node_uuid       | 5d946337-b1d9-4b06-8eda-4fb77e994a0d |
    | resource_class  | baremetal-large                      |
    | state           | active                               |
    | traits          | []                                   |
    | updated_at      | 2019-04-03T12:18:26+00:00            |
    | uuid            | e84f5d60-84f1-4701-a635-10ff90e2f3b0 |
    +-----------------+--------------------------------------+

.. note::
    Allocations in Ironic (including the earlier approach of using
    ``instance_uuid``) are cooperative. API consumers are required to set
    ``instance_uuid`` either directly or via the allocation API before doing
    anything with a node.

Now that you have an ``active`` allocation, you can proceed with the
deployment of the node specified in the ``node_uuid`` field, for example:

.. code-block:: console

    $ openstack baremetal node set 5d946337-b1d9-4b06-8eda-4fb77e994a0d \
        --instance-info image_source=https://images.local/image.img \
        --instance-info image_checksum=9dba20bace2bf54b63154a473feea422
    $ openstack baremetal node deploy 5d946337-b1d9-4b06-8eda-4fb77e994a0d \
        --config-drive /path/to/config/drive --wait

An error to allocate will be clearly communicated to you:

.. code-block:: console

    $ openstack baremetal allocation create --resource-class I-dont-exist --wait
    Allocation 34202b56-389a-4845-ae36-90e82a707adc failed: Failed to process allocation 34202b56-389a-4845-ae36-90e82a707adc: no available nodes match the resource class I-dont-exist.

Allocations are automatically deleted when an associated node is undeployed, so
usually you don't have to worry about them. If you decided not to deploy at
all (or if allocation has failed), delete the allocation:

.. code-block:: console

    $ openstack baremetal allocation delete 34202b56-389a-4845-ae36-90e82a707adc
    Deleted allocation 34202b56-389a-4845-ae36-90e82a707adc

Allocations and Traits
~~~~~~~~~~~~~~~~~~~~~~

Since we're aiming for compatibility with Nova, traits are also supported.

.. code-block:: console

    $ openstack baremetal allocation create --resource-class baremetal-large \
        --trait HW_CPU_X86_VMX --trait CUSTOM_OPENCV --wait
    +-----------------+---------------------------------------+
    | Field           | Value                                 |
    +-----------------+---------------------------------------+
    | candidate_nodes | []                                    |
    | created_at      | 2019-04-03T13:28:45+00:00             |
    | extra           | {}                                    |
    | last_error      | None                                  |
    | name            | None                                  |
    | node_uuid       | 3ddb8b0c-8cc2-4c23-8239-eeda4e93d07f  |
    | resource_class  | baremetal-large                       |
    | state           | active                                |
    | traits          | [u'HW_CPU_X86_VMX', u'CUSTOM_OPENCV'] |
    | updated_at      | 2019-04-03T13:28:45+00:00             |
    | uuid            | 7b3bd8bf-3a00-41a4-a018-69b620226629  |
    +-----------------+---------------------------------------+

This list of matched traits is automatically added to the node's
``instance_info`` for seamless integration with *Deploy Templates* in the
future:

.. code-block:: console

    $ openstack baremetal node show 3ddb8b0c-8cc2-4c23-8239-eeda4e93d07f --fields instance_info
    +---------------+----------------------------------------------------+
    | Field         | Value                                              |
    +---------------+----------------------------------------------------+
    | instance_info | {u'traits': [u'HW_CPU_X86_VMX', u'CUSTOM_OPENCV']} |
    +---------------+----------------------------------------------------+

And again, errors are pretty clear:

.. code-block:: console

    $ openstack baremetal allocation create --resource-class baremetal --trait CUSTOM_UNKNOWN --wait
    Allocation e34af6cb-1a4b-4437-a252-7aac560ab257 failed: Failed to process allocation e34af6cb-1a4b-4437-a252-7aac560ab257: no suitable nodes have the requested traits CUSTOM_UNKNOWN.

Candidate Nodes
~~~~~~~~~~~~~~~

There are just too many ways to choose nodes, we cannot cover them all in the
API. For example, a common request is to support *capabilities*, which are like
traits with values. To avoid bloating the API further, we have an ability to
provide a list of *candidate nodes* for an allocation

.. code-block:: console

    $ openstack baremetal allocation create --resource-class baremetal-large \
        --candidate-node ae1ebb09-a903-4199-8616-a0a5f3334203 \
        --candidate-node 3ddb8b0c-8cc2-4c23-8239-eeda4e93d07f --wait
    +-----------------+------------------------------------------------------------------------------------+
    | Field           | Value                                                                              |
    +-----------------+------------------------------------------------------------------------------------+
    | candidate_nodes | [u'ae1ebb09-a903-4199-8616-a0a5f3334203', u'3ddb8b0c-8cc2-4c23-8239-eeda4e93d07f'] |
    | created_at      | 2019-04-03T13:50:24+00:00                                                          |
    | extra           | {}                                                                                 |
    | last_error      | None                                                                               |
    | name            | None                                                                               |
    | node_uuid       | 3ddb8b0c-8cc2-4c23-8239-eeda4e93d07f                                               |
    | resource_class  | baremetal-large                                                                    |
    | state           | active                                                                             |
    | traits          | []                                                                                 |
    | updated_at      | 2019-04-03T13:50:24+00:00                                                          |
    | uuid            | 199a7e80-e688-4244-83de-ae9b21aac4a0                                               |
    +-----------------+------------------------------------------------------------------------------------+

This feature allows pre-filtering nodes based on any criteria.

Future Work
-----------

While the core allocation API is available, there is still work to be done:

* `Updating allocation name and extra
  <https://storyboard.openstack.org/#!/story/2005126>`_
* `Backfilling allocations for deployed nodes
  <https://storyboard.openstack.org/#!/story/2005014>`_
* Update metalsmith_ to use the allocation API

Something I would love to see done, but certainly won't have time for, is
adding Placement_ as an optional backend for the allocation API. This may
enable using Blazar_, the OpenStack reservation service, with Ironic directly,
rather than through Nova.

Finally, the idea of replacing direct updates of ``instance_info`` with a new
*deployment API* has been in the air for years.

.. _OpenStack Bare Metal (Ironic): https://docs.openstack.org/ironic/latest/
.. _Allocation API: https://developer.openstack.org/api-ref/baremetal/?expanded=create-allocation-detail#allocations-allocations
.. _TripleO: https://tripleo.org
.. _Placement: https://docs.openstack.org/placement/latest/
.. _baremetal flavor documentation: https://docs.openstack.org/ironic/latest/install/configure-nova-flavors.html
.. _os-traits: https://docs.openstack.org/os-traits/latest/user/index.html
.. _Bifrost: https://docs.openstack.org/bifrost/latest/
.. _metalsmith: https://docs.openstack.org/metalsmith/latest/
.. _Blazar: https://docs.openstack.org/blazar/latest/
