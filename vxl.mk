VPATH=/afs/e.kth.se/home/2002/map/sip/erlang/kth.se

all: $(BEAM) $(BOOT) $(STARTSCRIPT)

clean:
	rm -f *.beam *.boot *.app *.rel *~ *.script *.start

sslkey:
	mkdir ssl || true
	chmod 700 ssl
	echo "[ req ]" > ssl/ssl.config
	echo output_password=foobar >> ssl/ssl.config
	echo prompt=no >> ssl/ssl.config
	echo default_bits=1024 >> ssl/ssl.config
	echo default_md=sha1 >> ssl/ssl.config
	echo default_keyfile=privkey.pem >> ssl/ssl.config
	echo distinguished_name=req_distinguished_name >> ssl/ssl.config
	echo "[ req_distinguished_name ]" >> ssl/ssl.config
	echo "C=SE" >> ssl/ssl.config
	echo "L=Stockholm" >> ssl/ssl.config
	echo "O=KTH" >> ssl/ssl.config
	echo "OU=ITE" >> ssl/ssl.config
	echo "CN=`hostname`" >> ssl/ssl.config
	cd ssl && openssl req -new -text -out cert.req -config ./ssl.config
	cd ssl && openssl rsa -in privkey.pem -out cert.pem -passin pass:foobar
	cd ssl && openssl req -x509 -in cert.req -text -key cert.pem -out cert.cert
	cat ssl/cert.cert ssl/cert.pem > ssl/cert.comb

%.start:
	echo "#!/bin/sh" > $@
	echo ". /mpkg/modules/current/init/sh" >> $@
	echo "module add erlang" >> $@
	echo "erl -boot " $* " -name " $* " -proto_dist inet_ssl -ssl_dist_opt client_certfile ssl/cert.comb -ssl_dist_opt server_certfile ssl/cert.comb -ssl_dist_opt verify 2 -detached" >> $@
	chmod +x $@

%.app: %.app.in
	cp $< $@

%.rel: %.rel.in %.app
	cp $< $@

%.beam: %.erl
	erlc -W +debug_info $<

%.boot %.script: %.rel
	erl -noshell -run systools make_script $* -run init stop