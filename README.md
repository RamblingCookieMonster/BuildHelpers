# BuildHelpers

This is a PowerShell module with a variety of helper functions for PowerShell CI/CD scenarios.

Many of our build scripts explicitly reference build-system-specific features.  We might rely on $ENV:APPVEYOR_REPO_BRANCH to know which branch we're in, for example.

This certainly works, but we can enable more portable build scripts by normalizing these variables, and bundling up helper functions to help enable a more portable build script.
