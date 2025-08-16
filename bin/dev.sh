

		curr=$(pwd);
		export PATH="$PATH::$curr";

	#------------------------------------------------

		if [ -d "./bin" ]; then
			export PATH="$PATH::$curr/bin";
		fi


		if [ -f "./build.sh" ]; then 
			alias build='./build.sh';
		else
			printf "Build.sh not found on PATH"
		fi

	#------------------------------------------------




	#------------------------------------------------

		if [ -d "./parts" ]; then
			:
		fi

	#------------------------------------------------
