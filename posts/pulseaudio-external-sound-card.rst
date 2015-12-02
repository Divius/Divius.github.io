.. title: Configuring PulseAudio to switch to external sound card automatically
.. slug: pulseaudio-external-sound-card
.. date: 2015-12-02 20:20:19 UTC+01:00
.. tags: software
.. category: 
.. link: 
.. description: 
.. type: text

PulseAudio is a nice piece of software and has plenty of options for tuning
your desktop audio experience. Some defaults, however, may be confusing. As
any musician I use an external sound card a lot for both practice and
recording and manually switching to it every time is *really* annoying.
Now I've found a simple solution for this problem. Edit
``/etc/pulse/default.pa`` as root and append the following line::

    load-module module-switch-on-connect

Now restart PulseAudio with ``pulseaudio -k``. That's it, credit for the
solution goes to `this answer <load-module module-switch-on-connect>`_.
