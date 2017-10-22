for i in `docker inspect --format='{{.Name}}' $(docker ps -q) | cut -f2 -d\/`
        do container_name=$i

        # Creating container folder
        docker run -it --rm --user=$(id -u):$(id -g) \
        -v $PWD/config:/config \
        -v $backup_path:/workdir \
        peez/dropbox-uploader \
        mkdir $container_name

        # Uploading image


        echo -n "$container_name - image to Dropbox - "
        docker run -it --rm --user=$(id -u):$(id -g) \
        --name dropbox-$container_name-image-backup
        -v $PWD/config:/config \
        -v $backup_path:/workdir \
        peez/dropbox-uploader \
        upload $container_name/$container_name-image-$(date +'%Y%m%d').tar \
        $container_name/$container_name-image-$(date +'%Y%m%d').tar
        echo "OK"

        # remove local image

        rm $backup_path/$container_name/$container_name-image-$(date +'%Y%m%d').tar

        # Uploading volume
        echo -n "$container_name - volume to Dropbox - "

        docker run -it --rm --user=$(id -u):$(id -g) \
        --name dropbox-$container_name-volume-backup
        -v $PWD/config:/config \
        -v $backup_path:/workdir \
        peez/dropbox-uploader \
        upload $container_name/$container_name-volume-$(date +'%Y%m%d').tar.xz \
        $container_name/$container_name-volume-$(date +'%Y%m%d').tar.xz
        echo "OK"

        # remove local volume

        rm $backup_path/$container_name/$container_name-volume-$(date +'%Y%m%d').tar.xz
done
