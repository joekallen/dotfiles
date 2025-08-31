def delete-unused [
  type: string
  column: string
  names: list<string>
] {
  kubectl config $'get-($type)s' | from ssv | get name
  | where $it not-in $names
  | each { kubectl config $'delete-($type)' $in }
  | print
}

def set-cluster [
  name: string
  server: string
  ca: string
] {
  let args: list<string> = [
    $name
    $'--server=($server)'
  ]
  kubectl config set-cluster ...$args
  kubectl config set $'clusters.($name).certificate-authority-data' $ca
}

def set-credentials [
  name: string
  id: string
  region_short: string
  environment: string
] {
  let domain: string = if $name == 'k8s-streamspot-prod-us-east-1' { 'streamspot.io' } else { 'subsplash.io' }
  let oidc_issuer_host: string = [dex $id, $region_short, $environment, $domain] | str join '.'
  let args: list<string> = [
    $name
    --exec-api-version=client.authentication.k8s.io/v1beta1
    --exec-command=kubectl
    --exec-arg=oidc-login
    --exec-arg=get-token
    --exec-arg=--oidc-client-id=kubectl
    --exec-arg=--oidc-extra-scope=groups
    --exec-arg=--oidc-extra-scope=profile
    --exec-arg=--oidc-extra-scope=audience:server:client_id:kubernetes
    $'--exec-arg=--oidc-issuer-url=https://($oidc_issuer_host)'
  ]
  kubectl config set-credentials ...$args
}

def set-context [
  name: string
] {
  let args: list<string> = [$name $'--cluster=($name)' $'--user=($name)']
  kubectl config set-context ...$args
}

let cluster_names: list<string> = vault kv list -format='json' 'infra/discovery/k8s' | from json

let clusters = $cluster_names | each {
  vault kv get -format='json' $'infra/discovery/k8s/($in)' | from json | get data.data
}

delete-unused cluster name $cluster_names
delete-unused context NAME $cluster_names
delete-unused user NAME $cluster_names

$clusters | each { set-cluster $in.cluster_name $in.server $in.ca }
$clusters | each { set-credentials $in.cluster_name $in.cluster_id $in.region_short $in.env }
$clusters | each { set-context $in.cluster_name }

# let clusters_config = $clusters | each {
  # {
    # name: $in.cluster_name
    # cluster: {
      # server: $in.server
      # certificate-authority-data: $in.ca
    # }
  # }
# }
#
# let contexts_config = $clusters | each {
  # {
    # name: $in.cluster_name
    # cluster: {
      # server: $in.server
      # certificate-authority-data: $in.ca
    # }
  # }
# }
#
# let users_config = $clusters | each {
  # let domain: string = if $in.cluster_name == 'k8s-streamspot-prod-us-east-1' { 'streamspot.io' } else { 'subsplash.io' }
  # let oidc_issuer_host: string = [dex $in.cluster_id, $in.region_short, $in.env, $domain] | str join '.'
  # {
    # name: $in.cluster_name
    # user: {
      # exec: {
        # apiVersion: client.authentication.k8s.io/v1beta1
        # args: [
          # oidc-login
          # get-token
          # $'--oidc-issuer-url=https://($oidc_issuer_host)'
          # --oidc-client-id=kubectl
          # --oidc-extra-scope=groups
          # --oidc-extra-scope=profile
          # --oidc-extra-scope=audience:server:client_id:kubernetes
        # ]
        # command: kubectl
        # env: null
        # interactiveMode: IfAvailable
        # provideClusterInfo: false
      # }
    # }
  # }
# }
#
# let kube_config = {
  # apiVersion: v1
  # kind: Config
  # current-context: $current_cluster
  # preferences: {}
  # clusters: $clusters_config
  # contexts: $contexts_config
  # users: $users_config
# }
#
# $kube_config | save -f $'~/.kube/config.nu'
