# lab-windows-2019-vuln Build Process

## Important!

[`peru`](https://app.vagrantup.com/peru/) seems to regularly build new boxes off of the windows eval licenses, which
is great because their licenses only last 180 days from build time. So,
keep bumping the `box_version` in the vagrantfile and/or packerfile to point
to an unexpired peru box.

Note: `./scripts/configs/enable-audio-services.ps1` throws an error at one point, but
don't worry it's fine.

## Build a new version

use the `package.sh` script. It will set certain sysprep options and bundle
the vagrantfile template. After, run `vagrant cloud publish...`
