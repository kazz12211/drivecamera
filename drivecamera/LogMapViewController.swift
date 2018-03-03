//
//  LogMapViewController.swift
//  drivecamera
//
//  Created by Kazuo Tsubaki on 2018/03/03.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import UIKit
import MapKit

class LogMapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var exportButton: UIButton!
    
    var logURL: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true

        closeButton.layer.masksToBounds = true
        closeButton.layer.cornerRadius = 25
        closeButton.layer.opacity = 0.4
        closeButton.backgroundColor = UIColor.black
        closeButton.tintColor = UIColor.white
        
        exportButton.layer.masksToBounds = true
        exportButton.layer.cornerRadius = 25
        exportButton.layer.opacity = 0.4
        exportButton.backgroundColor = UIColor.black
        exportButton.tintColor = UIColor.white
        
        mapView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        showRoute()
    }

    private func calculateRegion(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var maxLat: CLLocationDegrees = 0
        var minLat: CLLocationDegrees = 0
        var maxLng: CLLocationDegrees = 0
        var minLng: CLLocationDegrees = 0
        for coordinate in coordinates {
            if maxLat == 0 { maxLat = coordinate.latitude } else { maxLat = max(maxLat, coordinate.latitude) }
            if minLat == 0 { minLat = coordinate.latitude } else { minLat = min(minLat, coordinate.latitude) }
            if maxLng == 0 { maxLng = coordinate.longitude } else { maxLng = max(maxLng, coordinate.longitude) }
            if minLng == 0 { minLng = coordinate.longitude } else { minLng = min(minLng, coordinate.longitude) }
        }
        let center = CLLocationCoordinate2DMake((maxLat + minLat) / 2, (maxLng + minLng) / 2)
        let span = MKCoordinateSpan(latitudeDelta: fabs(maxLat - minLat) * 1.1, longitudeDelta: fabs(maxLng - minLng) * 1.1)
        let region = MKCoordinateRegion(center: center, span: span)
        return region
    }
    
    private func showRoute() {
        let data = FileManager.default.contents(atPath: logURL.path)
        let str = String(data: data!, encoding: String.Encoding.utf8)
        let lines = str?.components(separatedBy: "\n")
        var coordinates: [CLLocationCoordinate2D] = []
        for line in lines! {
            let fields = line.components(separatedBy: ",")
            if(fields.count == 4) {
                let lat = Double(fields[1])
                let lng = Double(fields[2])
                let coordinate = CLLocationCoordinate2D(latitude: lat!, longitude: lng!)
                coordinates.append(coordinate)
            }
        }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.add(polyline, level: MKOverlayLevel.aboveRoads)

        let region = calculateRegion(coordinates: coordinates)
        mapView.region = region
        mapView.setCenter(region.center, animated: true)
    }
    
    func setLogURL(url: URL) {
        logURL = url
    }

    @IBAction func close(_ sender: Any) {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func export(_ sender: Any) {
        let av = UIActivityViewController(activityItems: [logURL], applicationActivities: nil)
        present(av, animated: true, completion: nil)
    }
}

extension LogMapViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let route:MKPolyline = overlay as! MKPolyline
        let routeRenderer:MKPolylineRenderer = MKPolylineRenderer(polyline: route)
        routeRenderer.lineWidth = 3.0
        routeRenderer.strokeColor = UIColor.blue
        return routeRenderer
    }

}
