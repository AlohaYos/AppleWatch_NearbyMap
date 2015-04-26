
#import "InterfaceController.h"


@interface InterfaceController() {
	
	NSTimer *intervalTimer;						// 地図の更新タイマー
	CLLocationManager *locationManager;			// ロケーションマネージャ
	CLLocationCoordinate2D userLocation;		// 現在位置
	BOOL			deferredLocationUpdates;	// Deferrdアップデートフラグ
	CLLocationCoordinate2D mapCenterLocation;	// 地図の中心位置
	MKCoordinateSpan span;						// 地図の表示範囲
	float	spanValue;

	BOOL			isMapFix;					// 地図表示固定
	BOOL			isMarkerFix;				// マーカー表示固定
}

@property (weak, nonatomic) IBOutlet WKInterfaceMap *mapView;

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context {
	[super awakeWithContext:context];
	
	// extensionのinfo.plistにUIBackGroundModes=locationを追加する
	
	// ユーザーに位置情報利用の承諾を得る
	locationManager = [CLLocationManager new];
	if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
		[locationManager requestAlwaysAuthorization];
		
		// iPhoneが手元にない場合（カバンの中など）を想定して、
		// iPhone側のメッセージをチェックするようにユーザーにメッセージを出す
		[self pushControllerWithName:@"AuthCheckInterfaceController" context:nil];
	}
	
	// 位置情報の取得開始
	locationManager.delegate = self;
	locationManager.activityType = CLActivityTypeFitness;
	locationManager.distanceFilter = kCLDistanceFilterNone;
	locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	[locationManager startUpdatingLocation];

	isMapFix = isMarkerFix = NO;
	
}

- (void)willActivate {
	[super willActivate];
	
	// マップの表示位置、表示範囲を設定
	spanValue = 0.01;

	[self refreshMapView];
	
	// 定期的に、現在地を中心にした地図に描きなおす
	if(intervalTimer==nil) {
		intervalTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkPosition) userInfo:nil repeats:YES];
	}
}

- (void)didDeactivate {
	
	// 地図の更新タイマーを停止
	if(intervalTimer) {
		[intervalTimer invalidate];
		intervalTimer = nil;
	}
	
	[super didDeactivate];
}

#pragma mark - Location manager delegate

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
	
	// 現在位置を取得
//	CLLocation *location = [locations firstObject];
//	userLocation = location.coordinate;
	
	// 2度つづけてallowDeferredLocationUpdatesUntilTraveledを呼ぶと最初のモノがキャンセルされるので、フラグで回避している
	if(!deferredLocationUpdates) {
		// Deferred更新に設定して、位置情報の収集頻度を減らす
		CLLocationDistance	distance = 100.0;	// meter
		NSTimeInterval		time = 30.0;		// sec
		[locationManager allowDeferredLocationUpdatesUntilTraveled:distance timeout:time];
		deferredLocationUpdates = YES;
	}
}

-(void)locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(NSError *)error
{
	// 次のDeferred更新の準備
	deferredLocationUpdates = NO;
	
	// 現在位置を取得
	userLocation = manager.location.coordinate;
	
	if(isMarkerFix==NO) {
		// マーカーを移動させる
		[self displayCenterAnnotation];
	}
}

#pragma mark - Map job

- (void)checkPosition {
	
	// アノテーションが地図の端に近づいた場合に地図の表示中心を更新する
	double latDiff = fabs(mapCenterLocation.latitude  - userLocation.latitude);
	double lonDiff = fabs(mapCenterLocation.longitude - userLocation.longitude);
	if((latDiff > spanValue*0.4)||(lonDiff > spanValue*0.4)) {
		// マップの表示位置、表示範囲を変更
		if(isMapFix==NO) {
			[self refreshMapView];
		}
	}
}

- (void)refreshMapView {
	
	// マップの表示位置、表示範囲を変更
	span.latitudeDelta = span.longitudeDelta = spanValue;
	MKCoordinateRegion region = {userLocation, span};
	[_mapView setRegion:region];
	mapCenterLocation = userLocation;
	
	[self displayCenterAnnotation];
}

// ズームアウト
- (IBAction)minusButtonPushed {
	
	spanValue += 0.01;
	
	[self refreshMapView];
}

// ズームイン
- (IBAction)plusButtonPushed {
	
	if(spanValue > 0.01) {
		spanValue -= 0.01;
	}
	else {
		if(spanValue > 0.001) {
			spanValue -= 0.001;
		}
	}
	
	[self refreshMapView];
}


#pragma mark - アノテーション処理

#if 1
// ＜パターン４＞ WatchKitアプリ側に全ての回転画像をバンドルして利用する場合
- (void)displayCenterAnnotation {
	
	// 現在地マーカーをいったん消去
	[_mapView removeAllAnnotations];
	
	// 進行方向を向いた矢印マーカーを、現在地に表示する
	
	// 進行方向を10°単位に
	int imageNo = locationManager.location.course / 10;
	// その角度に向いた矢印画像を選択
	NSString *imageName = [NSString stringWithFormat:@"arrow-%d.png", imageNo];
	// WatchKitアプリにバンドルされている画像を使ってアノテーションを表示する
	[_mapView addAnnotation:userLocation withImageNamed:imageName centerOffset:CGPointZero];
}
#endif

#if 0
// ＜パターン３＞ WatchKit Extension側で回転した矢印イメージをWatchKitアプリのキャッシュに保存して利用する場合
- (void)displayCenterAnnotation {
	
	// 現在地マーカーをいったん消去
	[_mapView removeAllAnnotations];
	
	// 進行方向を向いた矢印マーカー画像を作成
	int degree = locationManager.location.course;
	UIImage *img = [self rotateImage:[UIImage imageNamed:@"arrow"] degree:degree];
	
	// 画像に名前を付けてApple Watch内のキャッシュに保存する
	NSString *imageName = [NSString stringWithFormat:@"arrow-%d", degree];
	[[WKInterfaceDevice currentDevice] addCachedImage:img name:imageName];
	
	// 進行方向を向いた矢印マーカー（キャッシュ内）を、現在地に表示する
	[_mapView addAnnotation:userLocation withImageNamed:imageName centerOffset:CGPointZero];
}
#endif

#if 0
// ＜パターン２＞ WatchKit Extension側で回転した矢印イメージをWatchKitアプリへ転送して利用する場合
- (void)displayCenterAnnotation {
	
	// 現在地マーカーをいったん消去
	[_mapView removeAllAnnotations];
	
	// 進行方向を向いた矢印マーカーを、現在地に表示する
	int degree = locationManager.location.course;
	UIImage *img = [self rotateImage:[UIImage imageNamed:@"arrow"] degree:degree];
	[_mapView addAnnotation:userLocation withImage:img centerOffset:CGPointZero];
}
#endif

#if 0
// ＜パターン１＞ WatchKit標準のピンアノテーションを使用する場合
- (void)displayCenterAnnotation {
	
	// 現在地マーカーをいったん消去
	[_mapView removeAllAnnotations];
	
	// 進行方向を向いた矢印マーカーを、現在地に表示する
	[_mapView addAnnotation:userLocation withPinColor:WKInterfaceMapPinColorGreen];
}
#endif

// 画像を回転させる
- (UIImage*)rotateImage:(UIImage*)image degree:(int)degree {
	
	CGSize imgSize = {image.size.width, image.size.height};
	UIGraphicsBeginImageContext(imgSize);
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextTranslateCTM(context, image.size.width/2, image.size.height/2); // 回転の中心点を移動
	CGContextScaleCTM(context, 1.0, -1.0); // Y軸方向を補正
	
	float radian = -degree * M_PI / 180; // 回転
	CGContextRotateCTM(context, radian);
	CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(-image.size.width/2, -image.size.height/2, image.size.width, image.size.height), image.CGImage);
	
	UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	return rotatedImage;
}

#pragma mark - Menu

- (IBAction)fixMap {
	
	isMapFix = (isMapFix==YES?NO:YES);
}

- (IBAction)markerFix {
	
	isMarkerFix = (isMarkerFix==YES?NO:YES);
}


@end

