for i in `docker inspect --format='{{.Name}}' $(docker ps -q) | cut -f2 -d\/`
        do container_name=$i

        # Creating container folder
        docker run --rm --user=$(id -u):$(id -g) \
        -v $PWD/config:/config \
        -v $backup_path:/workdir \
        peez/dropbox-uploader \
        mkdir $container_name

        # Uploading image
        echo "$container_name - image to Dropbox "
        # TODO check if the file exists
        docker run --rm --user=$(id -u):$(id -g) \
        --name dropbox-$container_name-image-backup \
        -v $PWD/config:/config \
        -v $backup_path:/workdir \
        peez/dropbox-uploader \
        upload $container_name/$container_name-image.tar \
        $container_name/$container_name-image.tar && \

        # remove local image, TODO creating a condition to know if the file
        # uploaded well before deleting
        rm -f $backup_path/$container_name/$container_name-image.tar

        # Uploading volume
        echo "$container_name - volume to Dropbox "
        # TODO check if the file exists
        docker run --rm --user=$(id -u):$(id -g) \
        --name dropbox-$container_name-volume-backup \
        -v $PWD/config:/config \
        -v $backup_path:/workdir \
        peez/dropbox-uploader \
        upload $container_name/$container_name-volume.tar.xz \
        $container_name/$container_name-volume.tar.xz && \

        # remove local volume, TODO creating a condition to know if the file
        # uploaded well before deleting
        rm -f $backup_path/$container_name/$container_name-volume.tar.xz
done
