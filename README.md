To use this configuration you must first install OpenResty:
  https://openresty.org/en/getting-started.html

And update nginx.conf file with paths to your server environment.

The run the server use:

    sudo /usr/local/openresty/bin/openresty -p `pwd`/ -c ubidots-nginx/nginx.conf
    
To restart the server use:

    sudo /usr/local/openresty/bin/openresty -p `pwd`/ -c ubidots-nginx/nginx.conf -s reload

