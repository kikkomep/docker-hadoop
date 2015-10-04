#!/usr/bin/env bash

# default values
docker_host="0.0.0.0"
docker_port="3377"
docker_user="docker"
save_hosts=false
clean=false
public_only=false
host_only=false
container_only=false
output_file='/etc/hosts'

# docker command
docker_cmd="docker"

# print usage
usage() {
    echo "Usage: $0 [options] [service_port/service_protocol[,...]"
    echo "       Available options:"
    echo -e "\t   -h | --host <DOCKER_ADDRESS>   the default value is the current DOCKER_HOST address"
    echo -e "\t   -p | --port <DOCKER_PORT>      the default value is the current DOCKER_HOST port"
    echo -e "\t   -u | --user <DOCKER_USER>      the default value is 'docker'"
    echo -e "\t   --save-hosts                   save host entries on your from your file, e.g., /etc/hosts (default)"
    echo -e "\t   -o | --output <FILE>           file for saving host entries, e.g. /etc/hosts (default)"
    echo -e "\t   --public-only                  only public addresses"
    echo -e "\t   --host-only                    only host addresses"
    echo -e "\t   --container-only               only container addresses"
    echo -e "\t   --clean                        remove host entries from your file, e.g., /etc/hosts (default)"
    echo -e "\n\n"
    exit 1;
}

# parse arguments
OPTS=`getopt -o h:p:u:o: --long host:,port:,user:,save-hosts,clean,output:,public-only,host-only,container-only -n 'parse-options' -- "$@"`

# check parsing result
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; usage; exit 1 ; fi

# set default host and port values from $DOCKER_HOST
docker_host_info=($(echo ${DOCKER_HOST} | sed 's/tcp:\/\///' | tr ":" " "))
if [[ -n ${docker_host_info[0]} ]]; then
    docker_host=${docker_host_info[0]}
fi
if [[ -n ${docker_host_info[1]} ]]; then
    docker_port=${docker_host_info[1]}
fi


# process arguments
eval set -- "${OPTS}"
while true; do
  case "$1" in
    -h | --host ) docker_host="$2"; shift; shift ;;
    -p | --port ) docker_port="$2"; shift; shift ;;
    -u | --user ) docker_user="$2"; shift; shift ;;
    -o | --output ) output_file="$2"; shift; shift;;
    --save-hosts ) save_hosts=true; shift;;
    --public-only ) public_only=true; shift;;
    --host-only ) host_only=true; shift;;
    --container-only ) container_only=true; shift;;
    --clean ) clean=true; shift;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

# check output file path is not a dir
if [[ -d ${output_file} ]]; then
    echo "'${output_file}' is a directory!!!"
    usage
fi

# set docker_host option
if [[ -n ${docker_port} ]]; then
    docker_host_option="tcp://${docker_host}:${docker_port}"
fi

# infos of services
declare -a service_infos

#
function find_exposed_service_infos_by_port(){

    local service_port=$1;
    local service_protocol=$2;

    local service_containers_=$(${docker_cmd} ps | egrep [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:[0-9]+\-\>${service_port}/${service_protocol} | awk '{print $1}')
    local service_containers=$(echo ${service_containers_} | tr ' ' '\n' | sort -u | tr '\n' ' ')
    for service_id in ${service_containers}; do
        local service_hostname=$(${docker_cmd} inspect --format="{{ .Config.Hostname }}" ${service_id})
        local service_domain=$(${docker_cmd} inspect --format="{{ .Config.Domainname }}" ${service_id})
        local service_mapping=$(${docker_cmd} ps | egrep -o  [0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{1,3\}:[0-9]+\-\>${service_port}/${service_protocol})

        local service_public_ip=$(ssh ${docker_user}@${docker_host} curl ipinfo.io/ip)
        local service_container_ip=$(${docker_cmd} inspect --format="{{ .NetworkSettings.IPAddress }}" ${service_id})
        local service_fq_hostname=${service_hostname}
        if [[ -n ${service_domain} ]]; then
            service_fq_hostname="${service_hostname}.${service_domain}"
        fi
        if [[ ${service_container_ip} == "0.0.0.0" ]]; then
            service_container_ip=${docker_host}
        fi
        local service_host_ip=$(echo ${service_mapping} | cut -d':' -f1)
        if [[ ${service_host_ip} == "0.0.0.0" ]]; then
            service_host_ips=$(/sbin/ifconfig | egrep "inet (addr:)?" | awk '{print $2}' | tr '\n' '|')
        fi
        if [[ ${public_only} == true ]]; then
            service_infos=("${service_infos} ${service_id},${service_port},${service_port},${service_hostname},${service_domain},${service_fq_hostname},${service_public_ip}" )
        elif [[ ${container_only} == true ]]; then
            service_infos=("${service_infos} ${service_id},${service_port},${service_port},${service_hostname},${service_domain},${service_fq_hostname},${service_container_ip}" )
        elif [[ ${host_only} == true ]]; then
            service_infos=("${service_infos} ${service_id},${service_port},${service_port},${service_hostname},${service_domain},${service_fq_hostname},${service_host_ips}" )
        else
            service_infos=("${service_infos} ${service_id},${service_port},${service_port},${service_hostname},${service_domain},${service_fq_hostname},${service_container_ip}|${service_public_ip}|${service_host_ips}")
        fi

        # NOTE: decomment for debugging
#        echo "ID: ${service_id}"
#        echo "HOST: ${service_fq_hostname}"
#        echo "PORT: ${service_port}"
#        echo "Container IP: ${service_container_ip}"
#        echo "Public IP: ${service_public_ip}"
#        echo $services[@]
    done
    return 0;
}


# TODO: reformat output
function print_service_infos(){
    local index=$1;
    local service=$2;

    echo -e "${index}: ${service}"
}

# parse list of services
service_filter=$1
if [[ -n ${service_filter} ]]; then
    sf=$(echo ${service_filter} | tr ',' ' ')
    for i in ${sf[@]}; do
        s_pp=($(echo ${i} | tr '/' ' '))
        find_exposed_service_infos_by_port ${s_pp[0]} ${s_pp[1]}
    done
fi

# print infos of found services
if [[ ${#service_infos[@]} -gt 0 ]]; then
    echo -e "\n\n *** Found services:"
    let i=1
    for sf in ${service_infos[@]}; do
        print_service_infos ${i} ${sf}
        ((i++))
    done
fi

# tags for host table entries
START_TAG="##DOCKER-HADOOP-SERVICES##"
END_TAG="##DOCKER-HADOOP-SERVICE##"

# update the service host table
if [[ ${save_hosts} == true ]]; then
    table=${START_TAG}
    for i in ${service_infos[@]}; do
        IFS="," read -ra service <<< "${i}"
        for j in $(echo ${service[6]} | tr '|' ' '); do
            table="${table}\n${j}\t${service[5]}"
        done
    done
    table="${table}\n${END_TAG}"
    # print host entries
    echo -e "\n*** Host Entries ***"
    echo -e ${table}
    # save host entries to the $output_file
    sudo sed -i -f "/${START_TAG}/,/${END_TAG}/d" ${output_file}
    sudo -- sh -c "echo '${table}' >> ${output_file}"
fi


# clean the service host table
if [[ ${clean} == true ]]; then
    sudo sed -i -f "/${START_TAG}/,/${END_TAG}/d" ${output_file}
fi


