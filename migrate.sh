src=$HOME/Projects/owlet.today/talks
dest=./talks

for dname in $(ls $dest | grep -v reveal.js); do
    if [[ -f $src/$dname/index.html ]]; then
        echo Migrating $dname
        git rm -rf $dest/$dname
        mkdir -p $dest/$dname
        url="https://owlet.today/talks/$dname/"
        cat > $dest/$dname/index.html <<EOF
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="refresh" content="3; url='$url'" />
  </head>
  <body>
    <p>Content migrated to <a href="$url">$url</a>.</p>
  </body>
</html>
EOF
        git add $dest/$dname
    fi
done

src=$HOME/Projects/owlet.today/posts
dest=./posts

for post in $(ls $dest | grep .rst | grep -v blog-migrated); do
    echo Migrating $post
    title=$(awk -F ': ' '/\.\. title:/{ print $2 }' $dest/$post)
    date=$(awk -F ': ' '/\.\. date:/{ print $2 }' $dest/$post)
    git rm -f $dest/$post
    newname=$dest/${post/.rst/.html}
    url="https://owlet.today/posts/${post/.rst/}/"
    cat > $newname <<EOF
<html>
    <head>
        <title>$title</title>
        <meta name="date" content="$date" />
        <meta http-equiv="refresh" content="3; url='$url'" />
    </head>
    <body>
        <p>Content migrated to <a href="$url">$url</a>.</p>
    </body>
</html>
EOF
    git add $newname
done
