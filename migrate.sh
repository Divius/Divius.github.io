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
