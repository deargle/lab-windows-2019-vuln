# Important!

[`peru`](https://app.vagrantup.com/peru/) seems to regularly build new boxes off of the windows eval licenses, which
is great because their licenses only last 180 days from build time. So,
keep bumping the `box_version` in the vagrantfile and/or packerfile to point
to an unexpired peru box.

# Push a new version

  vagrant package
  vagrant cloud publish ...
