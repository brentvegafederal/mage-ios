//
//  MapUtils.m
//  MAGE
//
//  Created by Brian Osborn on 5/4/17.
//  Copyright © 2017 National Geospatial Intelligence Agency. All rights reserved.
//

#import "MapUtils.h"
#import "GPKGMapShapePoints.h"

@implementation MapUtils

+(double) lineToleranceWithMapView: (MKMapView *) mapView{
 
    CLLocationCoordinate2D l1 = [mapView convertPoint:CGPointMake(0,0) toCoordinateFromView:mapView];
    CLLocation *ll1 = [[CLLocation alloc] initWithLatitude:l1.latitude longitude:l1.longitude];
    CLLocationCoordinate2D l2 = [mapView convertPoint:CGPointMake(0,500) toCoordinateFromView:mapView];
    CLLocation *ll2 = [[CLLocation alloc] initWithLatitude:l2.latitude longitude:l2.longitude];
    double mpp = [ll1 distanceFromLocation:ll2] / 500.0;
    
    double tolerance = mpp * sqrt(2.0) * 20.0;
    
    return tolerance;
}

+ (BOOL) polygonHasKinks: (GPKGMapShapePoints *) mapShapePoints {
    NSObject<GPKGShapePoints> *shapePoints = [mapShapePoints.shapePoints.allValues objectAtIndex:0];
    NSArray *points = [shapePoints getPoints];
    if ([points count] < 3) return NO;
    GPKGMapPoint *lastPoint = [points lastObject];
    
    for (int i = 0; i < [points count] - 1; i++) {
        GPKGMapPoint *point1 = [points objectAtIndex:i];
        GPKGMapPoint *nextPoint1 = [points objectAtIndex:i+1];

        for (int k = 0; k < [points count] - 1; k++) {
            GPKGMapPoint *point2 = [points objectAtIndex:k];
            GPKGMapPoint *nextPoint2 = [points objectAtIndex:k+1];
            if (abs(i-k) == 1) {
                continue;
            }
            if (
                i == 0 &&
                k == [points count] - 2 &&
                point1.coordinate.longitude == lastPoint.coordinate.longitude &&
                point1.coordinate.latitude == lastPoint.coordinate.latitude
                ) {
                continue;
            }
            BOOL intersects = [MapUtils line1Start:CGPointMake(point1.coordinate.longitude, point1.coordinate.latitude) andEnd:CGPointMake(nextPoint1.coordinate.longitude, nextPoint1.coordinate.latitude) intersectsLine2Start:CGPointMake(point2.coordinate.longitude, point2.coordinate.latitude) andEnd:CGPointMake(nextPoint2.coordinate.longitude, nextPoint2.coordinate.latitude)];
            if (intersects) return YES;
        }
    }
    return NO;
}

+ (BOOL) line1Start: (CGPoint) line1Start andEnd: (CGPoint) line1End intersectsLine2Start: (CGPoint) line2Start andEnd: (CGPoint) line2End {
    CGFloat q =
    //Distance between the lines' starting rows times line2's horizontal length
    (line1Start.y - line2Start.y) * (line2End.x - line2Start.x)
    //Distance between the lines' starting columns times line2's vertical length
    - (line1Start.x - line2Start.x) * (line2End.y - line2Start.y);
    CGFloat d =
    //Line 1's horizontal length times line 2's vertical length
    (line1End.x - line1Start.x) * (line2End.y - line2Start.y)
    //Line 1's vertical length times line 2's horizontal length
    - (line1End.y - line1Start.y) * (line2End.x - line2Start.x);
    
    if( d == 0 )
        return NO;
    
    CGFloat r = q / d;
    
    q =
    //Distance between the lines' starting rows times line 1's horizontal length
    (line1Start.y - line2Start.y) * (line1End.x - line1Start.x)
    //Distance between the lines' starting columns times line 1's vertical length
    - (line1Start.x - line2Start.x) * (line1End.y - line1Start.y);
    
    CGFloat s = q / d;
    if( r < 0 || r > 1 || s < 0 || s > 1 )
        return NO;
    
    return YES;
}

+ (BOOL) rect: (CGRect) r ContainsLineStart: (CGPoint) lineStart andLineEnd: (CGPoint) lineEnd {
    /*Test whether the line intersects any of:
     *- the bottom edge of the rectangle
     *- the right edge of the rectangle
     *- the top edge of the rectangle
     *- the left edge of the rectangle
     *- the interior of the rectangle (both points inside)
     */
    return [MapUtils line1Start:lineStart andEnd:lineEnd intersectsLine2Start:CGPointMake(r.origin.x, r.origin.y) andEnd:CGPointMake(r.origin.x + r.size.width, r.origin.y)] ||
    [MapUtils line1Start:lineStart andEnd:lineEnd intersectsLine2Start:CGPointMake(r.origin.x + r.size.width, r.origin.y) andEnd:CGPointMake(r.origin.x + r.size.width, r.origin.y + r.size.height)] ||
    [MapUtils line1Start:lineStart andEnd:lineEnd intersectsLine2Start:CGPointMake(r.origin.x + r.size.width, r.origin.y + r.size.height) andEnd:CGPointMake(r.origin.x, r.origin.y + r.size.height)] ||
    [MapUtils line1Start:lineStart andEnd:lineEnd intersectsLine2Start:CGPointMake(r.origin.x, r.origin.y + r.size.height) andEnd:CGPointMake(r.origin.x, r.origin.y)] ||
    (CGRectContainsPoint(r, lineStart) && CGRectContainsPoint(r, lineEnd));
}

+ (StyledPolyline *) generatePolyline:(NSMutableArray *) path {
    NSInteger numberOfSteps = path.count;
    
    CLLocationCoordinate2D coordinates[numberOfSteps];
    
    for (NSInteger index = 0; index < numberOfSteps; index++) {
        NSNumber *y = path[index][0];
        NSNumber *x = path[index][1];
        coordinates[index] = CLLocationCoordinate2DMake([x doubleValue], [y doubleValue]);
    }
    
    return [StyledPolyline polylineWithCoordinates:coordinates count:path.count];
}


+ (StyledPolygon *) generatePolygon:(NSMutableArray *) coordinates {
    //exterior polygon
    NSMutableArray *exteriorPolygonCoordinates = coordinates[0];
    NSMutableArray *interiorPolygonCoordinates = [[NSMutableArray alloc] init];
    
    
    CLLocationCoordinate2D exteriorMapCoordinates[exteriorPolygonCoordinates.count];
    for (NSInteger index = 0; index < exteriorPolygonCoordinates.count; index++) {
        NSNumber *y = exteriorPolygonCoordinates[index][0];
        NSNumber *x = exteriorPolygonCoordinates[index][1];
        
        exteriorMapCoordinates[index] = CLLocationCoordinate2DMake([x doubleValue], [y doubleValue]);
    }
    
    //interior polygons
    NSMutableArray *interiorPolygons = [[NSMutableArray alloc] init];
    if (coordinates.count > 1) {
        [interiorPolygonCoordinates addObjectsFromArray:coordinates];
        [interiorPolygonCoordinates removeObjectAtIndex:0];
        MKPolygon *recursePolygon = [MapUtils generatePolygon:interiorPolygonCoordinates];
        [interiorPolygons addObject:recursePolygon];
    }
    
    StyledPolygon *exteriorPolygon;
    if (interiorPolygons.count > 0) {
        exteriorPolygon = [StyledPolygon polygonWithCoordinates:exteriorMapCoordinates count:exteriorPolygonCoordinates.count interiorPolygons:[NSArray arrayWithArray:interiorPolygons]];
    }
    else {
        exteriorPolygon = [StyledPolygon polygonWithCoordinates:exteriorMapCoordinates count:exteriorPolygonCoordinates.count];
    }
    
    return exteriorPolygon;
}


@end
