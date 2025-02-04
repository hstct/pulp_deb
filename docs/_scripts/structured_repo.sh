#!/usr/bin/env bash

set -ev

trap "rm frigg_1.0_ppc64.deb" EXIT

# download a package
wget https://fixtures.pulpproject.org/debian/pool/asgard/f/frigg/frigg_1.0_ppc64.deb

# upload the package
TASK_HREF=$(http --form $BASE_ADDR/pulp/api/v3/content/deb/packages/ file@frigg_1.0_ppc64.deb | jq -r .task)
wait_until_task_finished $BASE_ADDR$TASK_HREF
PACKAGE_HREF=$(http ${BASE_ADDR}${TASK_HREF} | jq -r ".created_resources[0]")

# create a repo and distribution
REPO_HREF=$(http ${BASE_ADDR}/pulp/api/v3/repositories/deb/apt/ name=myrepo | jq -r .pulp_href)
TASK_HREF=$(http ${BASE_ADDR}/pulp/api/v3/distributions/deb/apt/ name=myrepo base_path=myrepo repository=$REPO_HREF | jq -r .task)
wait_until_task_finished $BASE_ADDR$TASK_HREF

# create the necessary content (release, comp, architecture)
RELEASE_HREF=$(http ${BASE_ADDR}/pulp/api/v3/content/deb/releases/ distribution=mydist codename=mycodename suite=mysuite | jq -r .pulp_href)
# Note that creating the release is optional, but without it your published repo will use default values for the suite and the codename in the published Release file.
ARCH_HREF=$(http ${BASE_ADDR}/pulp/api/v3/content/deb/release_architectures/ distribution=mydist architecture=ppc64 | jq -r .pulp_href)
COMP_HREF=$(http ${BASE_ADDR}/pulp/api/v3/content/deb/release_components/ distribution=mydist component=mycomp | jq -r .pulp_href)
PKG_COMP_HREF=$(http ${BASE_ADDR}/pulp/api/v3/content/deb/package_release_components/ package=$PACKAGE_HREF release_component=$COMP_HREF | jq -r .pulp_href)

# add our content to the repository
TASK_HREF=$(http ${BASE_ADDR}${REPO_HREF}modify/ add_content_units:="[\"$RELEASE_HREF\", \"$COMP_HREF\", \"$PACKAGE_HREF\", \"$PKG_COMP_HREF\", \"$ARCH_HREF\"]" | jq -r .task)
wait_until_task_finished $BASE_ADDR$TASK_HREF

# publish our repo
TASK_HREF=$(http ${BASE_ADDR}/pulp/api/v3/publications/deb/apt/ repository=$REPO_HREF structured=true | jq -r .task)
wait_until_task_finished $BASE_ADDR$TASK_HREF

# check that our repo has one of the package index folders we would expect
http --check-status ${CONTENT_ADDR}/myrepo/dists/mydist/mycomp/binary-ppc64/
