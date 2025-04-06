install-debian:
	cat ./debian/install.sh | sh

install-osx:
	./osx/install.sh

tolocal:
	./osx/apply_to_local.sh

fromlocal:
	./osx/replicate_from_local.sh
