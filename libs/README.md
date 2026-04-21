# Third-Party Libraries

This directory contains bundled third-party libraries used by p5engine.

---

## TinySound
- **License**: BSD-2-Clause (see `LICENSE-TinySound.txt`)
- **Author**: Finn Kuusisto
- **Purpose**: Lightweight audio playback engine (WAV / OGG)
- **Source**: https://github.com/finnkuusisto/TinySound

## Processing Core
- **License**: GPL-2.0 / LGPL-2.1
- **Author**: Processing Foundation
- **Purpose**: Core Processing API and runtime
- **Source**: https://processing.org

## OGG Vorbis Support (for TinySound)

These three libraries together provide TinySound with the ability to load Ogg files
containing audio data in the Vorbis format.
All are licensed under the **LGPL-2.1** (see `COPYING`).

### JOrbis
Pure Java Ogg Vorbis decoder.
- **Source**: http://www.jcraft.com/jorbis/

### Tritonus Share
Tritonus is an implementation of the Java Sound API. Tritonus Share is a
collection of classes required by all Tritonus plug-ins.
- **Source**: http://www.tritonus.org

### VorbisSPI
VorbisSPI is a Java Service Provider Interface that adds OGG Vorbis support to
the Java platform.
- **Source**: http://www.javazoom.net/vorbisspi/vorbisspi.html
