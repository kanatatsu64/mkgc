if [ $# -ne 1 ]; then
    echo "usage: create-instance <hostname>"
    exit 1
fi

gcloud compute --project=celtic-fact-225222 \
    instances create $1 \
    --metadata serial-port-enable=1 \
    --hostname=$1.main.gc \
    --zone=asia-northeast1-b --machine-type=f1-micro \
    --network-interface network=default,subnet=default,network-tier=PREMIUM \
    --network-interface network=my-first-vpc,subnet=my-first-vpc-subnet,no-address,network-tier=PREMIUM \
    --maintenance-policy=MIGRATE --service-account=my-first-service-account@celtic-fact-225222.iam.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --image=debian-9-stretch-v20190124 --image-project=debian-cloud \
    --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=default-on-my-first-vpc \
    --metadata-from-file startup-script=$HOME/lib/gcp/setting.sh
