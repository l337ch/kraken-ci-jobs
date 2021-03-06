KRAKEN_CLUSTER_NAME=kraken_pr_builder-${BUILD_NUMBER}
KUBECONFIG=${WORKSPACE}/bin/clusters/${KRAKEN_CLUSTER_NAME}/kube_config

mkdir -p terraform/aws/${KRAKEN_CLUSTER_NAME}
cat > terraform/aws/${KRAKEN_CLUSTER_NAME}/terraform.tfvars << EOF
aws_user_prefix="${KRAKEN_USER_PREFIX}"
aws_access_key="${AWS_ACCESS_KEY_ID}"
aws_secret_key="${AWS_SECRET_ACCESS_KEY}"
kubernetes_binaries_uri = "${KUBE_BINARIES_URI}"
asg_wait_single = 60
asg_wait_total = 10
kraken_repo.commit_sha = "${ghprbActualCommit}"
EOF

# start kraken-up
KRAKEN_VERBOSE=true ${WORKSPACE}/bin/kraken-up.sh \
  --clustername "${KRAKEN_CLUSTER_NAME}" \
  --clustertype aws \
    --dmopts "\
      --driver amazonec2 \
      --amazonec2-access-key ${AWS_ACCESS_KEY_ID} \
      --amazonec2-instance-type m4.xlarge
      --amazonec2-region ${AWS_DEFAULT_REGION} \
      --amazonec2-secret-key ${AWS_SECRET_ACCESS_KEY} \
      --amazonec2-vpc-id ${KRAKEN_DEFAULT_VPC}" \
    --dmname "${PIPELET_DOCKERMACHINE}" \
    --dmshell bash

${WORKSPACE}/bin/kraken-connect.sh \
  --clustername "${KRAKEN_CLUSTER_NAME}" \
  --clustertype aws \
    --dmname "${PIPELET_DOCKERMACHINE}" \
    --dmshell bash

# run tests
bundle install
bundle exec cucumber --format pretty --format junit --out output/cucumber/junit KUBECONFIG=${KUBECONFIG} CUKE_CLUSTER=${KRAKEN_CLUSTER_NAME} features/*_aws.feature

# destroy cluster. destroy needs to succeed in the "build" step in order to fully verify everything.
# another destroy that will run only if build fails is done in the post build steps
${WORKSPACE}/bin/kraken-down.sh \
  --clustername "${KRAKEN_CLUSTER_NAME}" \
    --clustertype aws \
    --dmname "${PIPELET_DOCKERMACHINE}" \
    --dmshell bash
