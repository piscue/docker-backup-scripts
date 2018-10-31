for i in `docker inspect --format='{{.Name}}' $(docker ps -q) | cut -f2 -d\/`
        do container_name=$i
        echo -n "$container_name - "
        container_image=`docker inspect --format='{{.Config.Image}}' $container_name`
        mkdir -p $backup_path/$container_name
        save_file="$backup_path/$container_name/$container_name-image.tar"
        docker save -o $save_file $container_image
        echo "OK"
done
