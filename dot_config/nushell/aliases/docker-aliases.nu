# Attach local standard input, output, and error streams to a running container
export alias 'docker attach' = docker container attach
# Create a new image from a container's changes
export alias 'docker commit' = docker container commit
export alias 'docker cp' = docker container cp
# Create a new container
export alias 'docker create' = docker container create
# Inspect changes to files or directories on a container's filesystem
export alias 'docker diff' = docker container diff
# Execute a command in a running container
export alias 'docker exec' = docker container exec
# Export a container's filesystem as a tar archive
export alias 'docker export' = docker container export
# Display detailed information on one or more containers
export alias 'docker inspect' = docker container inspect
# Kill one or more running containers
export alias 'docker kill' = docker container kill
# Fetch the logs of a container
export alias 'docker logs' = docker container logs
# Pause all processes within one or more containers
export alias 'docker pause' = docker container pause
# List port mappings or a specific mapping for the container
export alias 'docker port' = docker container port
# Rename a container
export alias 'docker rename' = docker container rename
# Restart one or more containers
export alias 'docker restart' = docker container restart
# List containers
export alias 'docker ps' = docker container ls
# Remove one or more containers
export alias 'docker rm' = docker container rm
# Run a command in a new container
export alias 'docker run' = docker container run
# Start one or more stopped containers
export alias 'docker start' = docker container start
# Display a live stream of container(s) resource usage statistics
export alias 'docker stats' = docker container stats
# Stop one or more running containers
export alias 'docker stop' = docker container stop
# Display the running processes of a container
export alias 'docker top' = docker container top
# Unpause all processes within one or more containers
export alias 'docker unpause' = docker container unpause
# Update configuration of one or more containers
export alias 'docker update' = docker container update
# Block until one or more containers stop, then print their exit codes
export alias 'docker wait' = docker container wait

# Build an image from a Dockerfile
export alias 'docker build' = docker image build
# Show the history of an image
export alias 'docker history' = docker image history
# Create a tag TARGET_IMAGE that refers to SOURCE_IMAGE
export alias 'docker tag' = docker image tag
# List images
export alias 'docker images' = docker image ls
# Remove one or more images
export alias 'docker rmi' = docker image rm
# Download an image from a registry
export alias 'docker pull' = docker image pull
# Upload an image to a registry
export alias 'docker push' = docker image push
# Save one or more images to a tar archive (streamed to STDOUT by default)
export alias 'docker save' = docker image save

# Inspect changes to files or directories on a container's filesystem
export alias 'docker events' = docker system events
