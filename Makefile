install:
	make tools

tools:
	./osx/scripts/install.sh

tolocal:
	./osx/scripts/apply_to_local.sh

fromlocal:
	./osx/scripts/replicate_from_local.sh
