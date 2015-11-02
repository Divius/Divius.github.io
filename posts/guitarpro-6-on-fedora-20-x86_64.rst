.. title: GuitarPro 6 on Fedora 20 x86_64
.. slug: guitarpro-6-on-fedora-20-x86_64
.. date: 2014-03-07 22:23 UTC+01:00
.. tags: music, software
.. category: 
.. link: 
.. description: 
.. type: text

Well, since I started using Fedora, some things are harder than in Ubuntu. For
example, GuitarPro only provides i686 .deb installer which just does not work.

Here what you do:

#. Download .deb of GuitarPro

#. Open it as a simple archive, then open ``data.tar.gz`` inside

#. Go to ``./opt`` and extract GuitarPro6 to wherever you like

#. Download the following debs:

   http://packages.ubuntu.com/saucy/i386/libpng12-0/download
   http://packages.ubuntu.com/saucy/i386/libssl0.9.8/download

#. Open them, open ``data.tar.gz``, extract files for ``./lib`` into GuitarPro6 directory
   (you should have lots of .so files there already, now you should have 3 more + one symlink)

#. Also http://www.linux.com/community/blogs/128-desktops/494464 suggests you do::

    sudo yum -y install libstdc++.i686 mesa-libGL.i686 alsa-lib.i686 portaudio.i686 pulseaudio-libs.i686 libXrender.i686 glib2.i686 freetype.i686 fontconfig.i686 libgnomeui.i686 gtk2-engines.i686

That's it! Now just run ./GuitarPro

