//
//  MapTasks.swift
//  GMapsDemo
//
//  Created by Gabriel Theodoropoulos on 29/3/15.
//  Copyright (c) 2015 Appcoda. All rights reserved.
//

import UIKit

class MapTasks: NSObject {
   
    let baseURLGeocode = "https://maps.googleapis.com/maps/api/geocode/json?"
    
    var lookupAddressResults: [String:Any]!
    
    var fetchedFormattedAddress: String!
    
    var fetchedAddressLongitude: Double!
    
    var fetchedAddressLatitude: Double!
    
    let baseURLDirections = "https://maps.googleapis.com/maps/api/directions/json?"
    
    var selectedRoute: [String:Any]!
    
    var overviewPolyline: [String:Any]!
    
    var originCoordinate: CLLocationCoordinate2D!
    
    var destinationCoordinate: CLLocationCoordinate2D!
    
    var originAddress: String!
    
    var destinationAddress: String!
    
    var totalDistanceInMeters: UInt = 0
    
    var totalDistance: String!
    
    var totalDurationInSeconds: UInt = 0
    
    var totalDuration: String!
    
    
    override init() {
        super.init()
    }
    
    
    func geocodeAddress(_ address: String!, withCompletionHandler completionHandler: @escaping ((_ status: String, _ success: Bool) -> Void)) {
        if let lookupAddress = address {
            let geocodeURLString = baseURLGeocode + "address=" + lookupAddress
            let geocodeURL = URL(string: geocodeURLString)
            
            DispatchQueue.main.async(execute: { () -> Void in
                let geocodingResultsData = try? Data(contentsOf: geocodeURL!)
                
                do {
                    if let dictionary  = try JSONSerialization.jsonObject(with: geocodingResultsData!, options: .allowFragments) as? [String: Any]{
                        // Get the response status.
                        if let status = dictionary["status"] as? String {
                            if status == "OK" {
                                if let allResults = dictionary["results"] as? [[String:Any]]{
                                    self.lookupAddressResults = allResults.first
                                    
                                    // Keep the most important values.
                                    self.fetchedFormattedAddress = self.lookupAddressResults["formatted_address"] as! String
                                    let geometry = self.lookupAddressResults["geometry"] as! [String:Any]
                                    let location = geometry["location"] as! [String:Double]
                                    self.fetchedAddressLongitude = location["lng"]
                                    self.fetchedAddressLatitude = location["lat"]
                                }
                                completionHandler(status, true)
                            }
                            else {
                                completionHandler(status, false)
                            }
                        }
                    }
                    else{
                        completionHandler("", false)
                    }
                }catch{
                    print("error in JSONSerialization")
                    completionHandler("", false)
                }
            })
        }
        else {
            completionHandler("No valid address.", false)
        }
    }
    
    func getDirections(_ origin: String!, destination: String!, waypoints: [String]?, travelMode: TravelModes!, completionHandler: @escaping ((_ status: String, _ success: Bool) -> Void)) {
        
        if let originLocation = origin {
            if let destinationLocation = destination {
                var directionsURLString = baseURLDirections + "origin=" + originLocation + "&destination=" + destinationLocation
                
                if let routeWaypoints = waypoints {
                    directionsURLString += "&waypoints=optimize:true"
                    
                    for waypoint in routeWaypoints {
                        directionsURLString += "|" + waypoint
                    }
                }
                
                if (travelMode) != nil {
                    var travelModeString = ""
                    
                    switch travelMode.rawValue {
                    case TravelModes.walking.rawValue:
                        travelModeString = "walking"
                        
                    case TravelModes.bicycling.rawValue:
                        travelModeString = "bicycling"
                        
                    default:
                        travelModeString = "driving"
                    }
                    
                    
                    directionsURLString += "&mode=" + travelModeString
                }
                
                
                //directionsURLString = directionsURLString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
                
                let directionsURL = URL(string: directionsURLString)
                
                
                DispatchQueue.main.async(execute: { () -> Void in
                    do {
                        let directionsData = try? Data(contentsOf: directionsURL!)
                        
                        if let dictionary = try JSONSerialization.jsonObject(with: directionsData!, options: .allowFragments) as? [String: Any]{
                            // Get the response status.
                            if let status = dictionary["status"] as? String {
                                if status == "OK" {
                                    if let routes = dictionary["routes"] as? [[String:Any]]{
                                        self.selectedRoute = routes.first
                                        self.overviewPolyline = self.selectedRoute["overview_polyline"] as! [String:String]
                                        let legs = self.selectedRoute["legs"] as! [[String:Any]]
                                        let startLocationDictionary = legs.first?["start_location"] as! [String:Double]
                                        self.originCoordinate = CLLocationCoordinate2DMake(startLocationDictionary["lat"]!, startLocationDictionary["lng"]!)
                                        let endLocationDictionary = legs[legs.count - 1]["end_location"] as! [String:Double]
                                        self.destinationCoordinate = CLLocationCoordinate2DMake(endLocationDictionary["lat"]!, endLocationDictionary["lng"]!)
                                        self.originAddress = legs.first?["start_address"] as! String
                                        self.destinationAddress = legs[legs.count - 1]["end_address"] as! String
                                        self.calculateTotalDistanceAndDuration()
                                    }
                                    completionHandler(status, true)
                                }
                                else {
                                    completionHandler(status, false)
                                }
                            }
                        }
                        else{
                            completionHandler("", false)
                        }
                    }catch{
                        print("error in JSONSerialization")
                        completionHandler("", false)
                    }
                })
            }
            else {
                completionHandler("Destination is nil.", false)
            }
        }
        else {
            completionHandler("Origin is nil", false)
        }
    }
    
    
    func calculateTotalDistanceAndDuration() {
        let legs = self.selectedRoute["legs"] as! [[String:Any]]
        
        totalDistanceInMeters = 0
        totalDurationInSeconds = 0
        
        for leg in legs {
            let distance = leg["distance"] as! [String:Any]
            let duration = leg["duration"] as! [String:Any]
            totalDistanceInMeters += distance["value"] as! UInt
            totalDurationInSeconds += duration["value"] as! UInt
        }
        
        
        let distanceInKilometers: Double = Double(totalDistanceInMeters / 1000)
        totalDistance = "Total Distance: \(distanceInKilometers) Km"
        
        
        let mins = totalDurationInSeconds / 60
        let hours = mins / 60
        let days = hours / 24
        let remainingHours = hours % 24
        let remainingMins = mins % 60
        let remainingSecs = totalDurationInSeconds % 60
        
        totalDuration = "Duration: \(days) d, \(remainingHours) h, \(remainingMins) mins, \(remainingSecs) secs"
    }
    
    
}
