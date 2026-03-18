ANDROID_APP_ID := 1:831340514827:android:234d1c4c9cc93e0d2a810e
IOS_APP_ID := 1:831340514827:ios:aae1542e921272b72a810e
PROJECT := semya-a7d10
GROUP := testers

.PHONY: build-android build-ios build release-android release-ios release deploy-functions deploy-firebase bump-build

build-android:
	flutter build apk --release

build-ios:
	flutter build ipa --release --export-method development

build:
	$(MAKE) build-android & $(MAKE) build-ios & wait

release-android:
	flutter build apk --release
	firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
		--app $(ANDROID_APP_ID) --groups $(GROUP) --project $(PROJECT)

bump-build:
	@BUILD=$$(grep '^version:' pubspec.yaml | sed 's/.*+//'); \
	VERSION=$$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//'); \
	NEW_BUILD=$$((BUILD+1)); \
	sed -i '' "s/version: $$VERSION+$$BUILD/version: $$VERSION+$$NEW_BUILD/" pubspec.yaml; \
	echo "Bumped build: $$VERSION+$$BUILD -> $$VERSION+$$NEW_BUILD"

release-ios:
	flutter build ipa --release --export-method development
	firebase appdistribution:distribute build/ios/ipa/semya.ipa \
		--app $(IOS_APP_ID) --groups $(GROUP) --project $(PROJECT)

release: bump-build
	$(MAKE) release-android & $(MAKE) release-ios & wait

deploy-functions:
	firebase deploy --only functions --project $(PROJECT)

deploy-firebase:
	firebase deploy --only functions,firestore,storage --project $(PROJECT)
