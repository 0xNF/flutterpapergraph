echo "Building Simple Auth Flow (user)"
flutter build web --release --base-href "/simple_auth_1/"
rm -rf build/simple_auth_1
cp -r build/web build/simple_auth_1