//
//  ViewController.swift
//  GMapsDemo
//
//  Created by Gabriel Theodoropoulos on 29/3/15.
//  Copyright (c) 2015 Appcoda. All rights reserved.
//

import UIKit


enum TravelModes: Int {
    case driving
    case walking
    case bicycling
}


class ViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate {

    @IBOutlet weak var viewMap: GMSMapView!
    
    @IBOutlet weak var lblInfo: UILabel!
    
    
    var locationManager = CLLocationManager()
    
    var didFindMyLocation = false
    
    var mapTasks = MapTasks()
    
    var locationMarker: GMSMarker!
    
    var originMarker: GMSMarker!
    
    var destinationMarker: GMSMarker!
    
    var routePolyline: GMSPolyline!
    
    var markersArray: [GMSMarker] = []
    
    var waypointsArray: [String] = []
    
    var travelMode = TravelModes.driving
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        let camera: GMSCameraPosition = GMSCameraPosition.camera(withLatitude: 48.857165, longitude: 2.354613, zoom: 8.0)
        viewMap.camera = camera
        viewMap.delegate = self
        
        viewMap.addObserver(self, forKeyPath: "myLocation", options: NSKeyValueObservingOptions.new, context: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if !didFindMyLocation {
            let myLocation = change?[NSKeyValueChangeKey.newKey] as! CLLocation
            viewMap.camera = GMSCameraPosition.camera(withTarget: myLocation.coordinate, zoom: 10.0)
            viewMap.settings.myLocationButton = true

            didFindMyLocation = true
        }
    }
    
    
    // MARK: IBAction method implementation
    
    @IBAction func changeMapType(_ sender: AnyObject) {
        let actionSheet = UIAlertController(title: "Map Types", message: "Select map type:", preferredStyle: UIAlertControllerStyle.actionSheet)
        
        let normalMapTypeAction = UIAlertAction(title: "Normal", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            self.viewMap.mapType = kGMSTypeNormal
        }
        
        let terrainMapTypeAction = UIAlertAction(title: "Terrain", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            self.viewMap.mapType = kGMSTypeTerrain
        }
        
        let hybridMapTypeAction = UIAlertAction(title: "Hybrid", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            self.viewMap.mapType = kGMSTypeHybrid
        }
        
        let cancelAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
            
        }
        
        actionSheet.addAction(normalMapTypeAction)
        actionSheet.addAction(terrainMapTypeAction)
        actionSheet.addAction(hybridMapTypeAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    
    @IBAction func findAddress(_ sender: AnyObject) {
        let addressAlert = UIAlertController(title: "Address Finder", message: "Type the address you want to find:", preferredStyle: UIAlertControllerStyle.alert)
        
        addressAlert.addTextField { (textField) -> Void in
            textField.placeholder = "Address?"
        }
        
        let findAction = UIAlertAction(title: "Find Address", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            let address = (addressAlert.textFields![0] as UITextField).text! as String
            
            self.mapTasks.geocodeAddress(address, withCompletionHandler: { (status, success) -> Void in
                if !success {
                    print(status)
                    
                    if status == "ZERO_RESULTS" {
                        self.showAlertWithMessage("The location could not be found.")
                    }
                }
                else {
                    let coordinate = CLLocationCoordinate2D(latitude: self.mapTasks.fetchedAddressLatitude, longitude: self.mapTasks.fetchedAddressLongitude)
                    self.viewMap.camera = GMSCameraPosition.camera(withTarget: coordinate, zoom: 14.0)
                    
                    self.setupLocationMarker(coordinate)
                }
            })
            
        }
        
        let closeAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
            
        }
        
        addressAlert.addAction(findAction)
        addressAlert.addAction(closeAction)
        
        present(addressAlert, animated: true, completion: nil)
    }
    
    
    @IBAction func createRoute(_ sender: AnyObject) {
        let addressAlert = UIAlertController(title: "Create Route", message: "Connect locations with a route:", preferredStyle: UIAlertControllerStyle.alert)
        
        addressAlert.addTextField { (textField) -> Void in
            textField.placeholder = "Origin?"
        }
        
        addressAlert.addTextField { (textField) -> Void in
            textField.placeholder = "Destination?"
        }
        
        
        let createRouteAction = UIAlertAction(title: "Create Route", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            if (self.routePolyline) != nil {
                self.clearRoute()
                self.waypointsArray.removeAll(keepingCapacity: false)
            }
            
            let origin = (addressAlert.textFields![0] as UITextField).text! as String
            let destination = (addressAlert.textFields![1] as UITextField).text! as String
            
            self.mapTasks.getDirections(origin, destination: destination, waypoints: nil, travelMode: self.travelMode, completionHandler: { (status, success) -> Void in
                if success {
                    self.configureMapAndMarkersForRoute()
                    self.drawRoute()
                    self.displayRouteInfo()
                }
                else {
                    print(status)
                }
            })
        }
        
        let closeAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
            
        }
        
        addressAlert.addAction(createRouteAction)
        addressAlert.addAction(closeAction)
        
        present(addressAlert, animated: true, completion: nil)
    }
    
    
    @IBAction func changeTravelMode(_ sender: AnyObject) {
        let actionSheet = UIAlertController(title: "Travel Mode", message: "Select travel mode:", preferredStyle: UIAlertControllerStyle.actionSheet)
        
        let drivingModeAction = UIAlertAction(title: "Driving", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            self.travelMode = TravelModes.driving
            self.recreateRoute()
        }
        
        let walkingModeAction = UIAlertAction(title: "Walking", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            self.travelMode = TravelModes.walking
            self.recreateRoute()
        }
        
        let bicyclingModeAction = UIAlertAction(title: "Bicycling", style: UIAlertActionStyle.default) { (alertAction) -> Void in
            self.travelMode = TravelModes.bicycling
            self.recreateRoute()
        }
        
        let closeAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
            
        }
        
        actionSheet.addAction(drivingModeAction)
        actionSheet.addAction(walkingModeAction)
        actionSheet.addAction(bicyclingModeAction)
        actionSheet.addAction(closeAction)
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    
    // MARK: CLLocationManagerDelegate method implementation
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == CLAuthorizationStatus.authorizedWhenInUse {
            viewMap.isMyLocationEnabled = true
        }
    }
    
    
    // MARK: Custom method implementation
    
    func showAlertWithMessage(_ message: String) {
        let alertController = UIAlertController(title: "GMapsDemo", message: message, preferredStyle: UIAlertControllerStyle.alert)
        
        let closeAction = UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel) { (alertAction) -> Void in
            
        }
        
        alertController.addAction(closeAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    
    func setupLocationMarker(_ coordinate: CLLocationCoordinate2D) {
        if locationMarker != nil {
            locationMarker.map = nil
        }
        
        locationMarker = GMSMarker(position: coordinate)
        locationMarker.map = viewMap
        
        locationMarker.title = mapTasks.fetchedFormattedAddress
        locationMarker.appearAnimation = kGMSMarkerAnimationPop
        locationMarker.icon = GMSMarker.markerImage(with: UIColor.blue)
        locationMarker.opacity = 0.75
        
        locationMarker.isFlat = true
        locationMarker.snippet = "The best place on earth."
    }
    
    
    func configureMapAndMarkersForRoute() {
        viewMap.camera = GMSCameraPosition.camera(withTarget: mapTasks.originCoordinate, zoom: 9.0)
        
        originMarker = GMSMarker(position: self.mapTasks.originCoordinate)
        originMarker.map = self.viewMap
        originMarker.icon = GMSMarker.markerImage(with: UIColor.green)
        originMarker.title = self.mapTasks.originAddress
        
        destinationMarker = GMSMarker(position: self.mapTasks.destinationCoordinate)
        destinationMarker.map = self.viewMap
        destinationMarker.icon = GMSMarker.markerImage(with: UIColor.red)
        destinationMarker.title = self.mapTasks.destinationAddress
        
        
        if waypointsArray.count > 0 {
            for waypoint in waypointsArray {
                let lat: Double = (waypoint.components(separatedBy: ",")[0] as NSString).doubleValue
                let lng: Double = (waypoint.components(separatedBy: ",")[1] as NSString).doubleValue
                
                let marker = GMSMarker(position: CLLocationCoordinate2DMake(lat, lng))
                marker?.map = viewMap
                marker?.icon = GMSMarker.markerImage(with: UIColor.purple)
                
                markersArray.append(marker!)
            }
        }
    }
    
    
    func drawRoute() {
        let route = mapTasks.overviewPolyline["points"] as! String
        
        let path: GMSPath = GMSPath(fromEncodedPath: route)
        routePolyline = GMSPolyline(path: path)
        routePolyline.map = viewMap
    }
    
    
    func displayRouteInfo() {
        lblInfo.text = mapTasks.totalDistance + "\n" + mapTasks.totalDuration
    }
    
    
    func clearRoute() {
        originMarker.map = nil
        destinationMarker.map = nil
        routePolyline.map = nil
        
        originMarker = nil
        destinationMarker = nil
        routePolyline = nil
        
        if markersArray.count > 0 {
            for marker in markersArray {
                marker.map = nil
            }
            
            markersArray.removeAll(keepingCapacity: false)
        }
    }
    
    
    func recreateRoute() {
        if (routePolyline) != nil {
            clearRoute()
            
            mapTasks.getDirections(mapTasks.originAddress, destination: mapTasks.destinationAddress, waypoints: waypointsArray, travelMode: travelMode, completionHandler: { (status, success) -> Void in
                
                if success {
                    self.configureMapAndMarkersForRoute()
                    self.drawRoute()
                    self.displayRouteInfo()
                }
                else {
                    print(status)
                }
            })
        }
    }
    
    
    // MARK: GMSMapViewDelegate method implementation
    
    func mapView(_ mapView: GMSMapView!, didTapAt coordinate: CLLocationCoordinate2D) {
        if (routePolyline) != nil {
            let positionString = String(format: "%f", coordinate.latitude) + "," + String(format: "%f", coordinate.longitude)
            waypointsArray.append(positionString)

            recreateRoute()
        }
    }
    
}

