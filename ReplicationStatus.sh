#get inputs from args
while getopts ":t:g:r:" opt; do
  case $opt in
    t) tenant="$OPTARG"
    ;;
    g) genevaAccount="$OPTARG"
    ;;
    r) roleInstance="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

echo "Path: $PATH"
echo "Tenant: $tenant"
echo "GenevaAccount: $genevaAccount"
echo "RoleInstance: $roleInstance"

ghe-repl-status

if [ $? -eq 0 ]
then
        date
        echo "Sending 0"
        echo '{"Account":"$genevaAccount","Namespace":"GHPIMetrics","Metric":"ReplicationStatus","Dims":{"Tenant":"$tenant","Role":"GHPI","Role_Instance":"$roleInstance"}}:0|g' | socat -t 1 - UDP-SENDTO:127.0.0.1:8126

else
      date
       echo "Sending 1"
       echo '{"Account":"$genevaAccount","Namespace":"GHPIMetrics","Metric":"ReplicationStatus","Dims":{"Tenant":"$tenant","Role":"GHPI","Role_Instance":""}}:1|g' | socat -t 1 - UDP-SENDTO:127.0.0.1:8126

fi
