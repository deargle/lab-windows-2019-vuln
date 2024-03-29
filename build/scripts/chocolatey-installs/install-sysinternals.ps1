Set-PSDebug -Trace 1
choco feature enable -n allowGlobalConfirmation
# https://community.chocolatey.org/packages/sysinternals#versionhistory
# the choco sysinternals package has a long history of failing checksums
# because of their update process.
choco install sysinternals --ignorechecksums
choco install reshack --ignorechecksums
choco install dependencywalker --ignorechecksums
choco install hxd --ignorechecksums
choco feature disable -n allowGlobalConfirmation
