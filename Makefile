

all:
	cat samples/simple.cpz | ./compz
	cat samples/proc.cpz | ./compz
	cat samples/complex.cpz | ./compz

deps:
	sudo apt-get install libparse-recdescent-perl
