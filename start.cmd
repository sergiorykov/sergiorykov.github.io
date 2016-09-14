where jekyll

pushd %~dp0
	rem run as admin
	start cmd /k "jekyll s"
	sleep 10
	start http://localhost:4000/
popd
