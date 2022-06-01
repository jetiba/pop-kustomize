# Creates 3 GKE autopilot clusters
# Initializes APIS, sets up the Google Cloud Deploy pipeline
# fail if PROJECT_ID is not set
if [[ -z "${PROJECT_ID}" ]]; then
  echo "The value of PROJECT_ID is not set. Be sure to run export PROJECT_ID=YOUR-PROJECT first"
  return
fi
# Test cluster

echo "creating networks and subnets ..."
gcloud compute networks create vpc --subnet-mode=custom
gcloud compute networks subnets create subnet-test --network vpc --range 10.10.0.0/16 --region europe-west8
gcloud compute networks subnets create subnet-staging --network vpc --range 10.11.0.0/16 --region europe-west8
gcloud compute networks subnets create subnet-product --network vpc --range 10.12.0.0/16 --region europe-west8

echo "creating testcluster..."
gcloud beta container --project "$PROJECT_ID" clusters create-auto "testcluster" \
--region "europe-west8" --release-channel "regular" --network "projects/$PROJECT_ID/global/networks/vpc" \
--subnetwork "projects/$PROJECT_ID/regions/europe-west8/subnetworks/subnet-test" \
--cluster-ipv4-cidr "/17" --services-ipv4-cidr "/22" --enable-private-nodes --master-ipv4-cidr "172.16.0.0/28" --async
# Staging cluster
echo "creating stagingcluster..."
gcloud beta container --project "$PROJECT_ID" clusters create-auto "stagingcluster" \
--region "europe-west8" --release-channel "regular" --network "projects/$PROJECT_ID/global/networks/vpc" \
--subnetwork "projects/$PROJECT_ID/regions/europe-west8/subnetworks/subnet-staging" \
--cluster-ipv4-cidr "/17" --services-ipv4-cidr "/22" --enable-private-nodes --master-ipv4-cidr "172.17.0.0/28" --async
# Prod cluster
echo "creating prodcluster..."
gcloud beta container --project "$PROJECT_ID" clusters create-auto "prodcluster" \
--region "europe-west8" --release-channel "regular" --network "projects/$PROJECT_ID/global/networks/vpc" \
--subnetwork "projects/$PROJECT_ID/regions/europe-west8/subnetworks/subnet-product" \
--cluster-ipv4-cidr "/17" --services-ipv4-cidr "/22" --enable-private-nodes --master-ipv4-cidr "172.18.0.0/28" --async
echo "Creating clusters! Check the UI for progress"

echo "creating Cloud NAT..."
gcloud compute routers create rout --region europe-west8 --network vpc --project=e2e-cicd 
gcloud beta compute routers nats create nat --router=rout --region=europe-west8 --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges --project=e2e-cicd

echo "configure permission for clusters to write metrics and logs in Cloud Ops"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$(gcloud projects describe $PROJECT_ID \
    --format="value(projectNumber)")-compute@developer.gserviceaccount.com \
    --role="roles/logging.logWriter"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:$(gcloud projects describe $PROJECT_ID \
    --format="value(projectNumber)")-compute@developer.gserviceaccount.com \
    --role="roles/monitoring.metricWriter"