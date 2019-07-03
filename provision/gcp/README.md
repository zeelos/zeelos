# login
gcloud auth login

# set current project-id
gcloud config set project phrasal-clover-243814

# set compute zone
gcloud config set compute/zone europe-west3

# set compute region
gcloud config set compute/region europe-west3-a

# add key
pbcopy < ~/.ssh/id_rsa.pub
add to 'Metadata' page -> https://console.cloud.google.com/compute/metadata/sshKeys
