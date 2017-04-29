where jekyll

pushd %~dp0
	rem run as admin
	start cmd /k "jekyll s --port 4000 --host 0.0.0.0 --watch"
	sleep 10
	start http://localhost:4000/
	rem start http://77.37.146.206:4000/
popd
