#!/bin/sh

# Clear the terminal screen.
clear

echo "|||||||||||||||||||||||||||||||||||||||||||||||||||"
echo "||||+-+-+-+-+-+-+-+-+-+-+-+-+-+|+-+-+-+-+-+-+-+||||"
echo "|||||C r o s s P a c k - A V R | C l e a n u p|||||"
echo "||||+-+-+-+-+-+-+-+-+-+-+-+-+-+|+-+-+-+-+-+-+-+||||"
echo "|||||||||||||||||||||||||||||||||||||||||||||||||||"

if [[ $(id -u) != 0 ]]; then
	echo "Please type your password so that we can run as root."
	echo "Exiting with status code 1.\n"
	exit 1
fi

if [ ! -x ./mkclean.sh ]; then
    echo "mkclean.sh must be called from the current directory as ./mkclean.sh"
    echo "Exiting with status code 2.\n"
    exit 2
fi

echo "Are you sure you want \x1B[1mclean\x1B[0m the directory?"
echo "This will \x1B[1mremove\x1B[0m the following directories in this"
echo "folder:"
echo "   -compile"
echo "   -math"
echo "   -temporary-install"
echo "   -patches"
echo "   -manual"
echo "   -packages\n"

echo "[\x1B[1mY\x1B[0m/\x1B[1mN\x1B[0m]"

read proceed

if [ $proceed = "y" ] || [ $proceed = "Y" ]; then
	echo "\x1B[32mProceeding with clean operation....\x1B[0m"
	rm -rf compile math temporary-install patches manual packages
else
	echo "\x1B[1;31mCanceling clean operation.\x1B[0m"
fi

echo "\x1B[1;32mDONE\x1B[0m\n"
