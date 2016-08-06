//
//  ViewController.swift
//  overlayPractice
//
//  Created by Anna Rogers on 8/6/16.
//  Copyright © 2016 Anna Rogers. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var worldMap: MKMapView!
    
    var Mali = Country()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        print("mali", Mali)
        addBoundary()
    }

    func addBoundary() {
        let polygon = MKPolygon(coordinates: &Mali.boundary, count: Mali.boundaryPointsCount)
        worldMap.addOverlay(polygon)
    }
    
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        //let overlayView: MKOverlayRenderer?
        if overlay is MKPolygon {
            let polygonView = MKPolygonRenderer(overlay: overlay)
            polygonView.strokeColor = UIColor.magentaColor()
            polygonView.fillColor = UIColor.greenColor()
            polygonView.alpha = 0.5
            return polygonView
        }
        return MKOverlayRenderer()
    }

}


