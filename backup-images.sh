for i in `docker inspect --format='{{.Name}}' $(docker ps -q) | cut -f2 -d\/`
        do container_name=$i
        echo -n "$container_name - "
        container_image=`docker inspect --format='{{.Config.Image}}' $container_name`
        mkdir -p $backup_path/$container_name
        save_file="$backup_path/$container_name/$container_name-image-$(date +'%Y%m%d').tar"
        docker save -o $save_file $container_image
        echo "OK"
        # create a container that does md5
        #md5sum $save_file $save_file.md5
        #echo "md5"
done
