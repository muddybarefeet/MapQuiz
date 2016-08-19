//
//  MapViewController.swift
//  overlayPractice
//
//  Created by Anna Rogers on 8/6/16.
//  Copyright © 2016 Anna Rogers. All rights reserved.
//

//    let continentCodes = [
//        "AF": "Africa",
//        "AN": "Antarctica",
//        "AS": "Asia",
//        "EU": "Europe",
//        "NA": "North America",
//        "OC": "Oceania",
//        "SA": "South America"
//    ]

import UIKit
import MapKit
import CoreData

class MapViewController: CoreDataController {

    @IBOutlet weak var worldMap: MKMapView!
    
    let Helpers = HelperFunctions.sharedInstance
    
    var continent: String!
    
    var currentGame: Game!
    var restoreOccur: Bool?
    
    var totalCountries: Int = 0
    
    var game = [
        "guessed": [String:String](),
        "toPlay": [String:String]()
    ]
    var revealed = 0
    var misses = 0
    
    var toFind = ""
    //question label
    let label = UILabel()
    
    //dictionary keyed by country name with the values as an array of all the polygons for that country
    var createdPolygonOverlays = [String: [MKPolygon]]()
    //dictionary keyed by country name with values of the coordinates of each country (for the contains method to use to check if clicked point is within one of the overlays)
    var coordinates = [ String: [[CLLocationCoordinate2D]] ]()
    
    var mapDelegate = MapViewDelegate()
    var entities: [LandArea]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        worldMap.delegate = mapDelegate
        
        //customize the navigation bar buttons
        self.navigationItem.hidesBackButton = true
        let newBackButton: UIBarButtonItem = UIBarButtonItem(image: UIImage(named: "back"), style: .Plain, target: self, action: #selector(self.returnToMainMenue))
        self.navigationItem.leftBarButtonItem = newBackButton
        
        //1. load all the countries for the selected continent into createdPolygonOverlays dictionary
        let app = UIApplication.sharedApplication().delegate as! AppDelegate
        let land = app.landAreas
        let fetchRequest = NSFetchRequest(entityName: "LandArea")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: land.context, sectionNameKeyPath: nil, cacheName: nil)
        entities = fetchedResultsController!.fetchedObjects as! [LandArea]
        print("entities: ", entities.count)
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(MapViewController.overlaySelected))
        view.addGestureRecognizer(gestureRecognizer)
        
        worldMap.mapType = .Satellite
    }
    
    override func viewWillAppear(animated: Bool) {
        
        for entity in entities {
            if (entity.continent == continent) {
                let country = Country(name: entity.name!, points: entity.coordinates!, coordType: entity.coordinate_type!)
                game["toPlay"]![entity.name!] = entity.name
                addBoundary(country)
                let region = Helpers.setZoomForContinent(continent)
                worldMap.setRegion(region, animated: true)
            }
        }
        totalCountries = createdPolygonOverlays.count
        // show countries guessed count to user
        self.title = String("0 / \(totalCountries)")
        print("<><><><><>",game["toPlay"]!.count)
        
        // 2. if restore then get the existing game else if not restore then make a new game
        if (restoreOccur == true) {
            restoreOccur = false
            print("data is saved go get it")
            // if the game has already been partially played then set up old scores
            if currentGame.attempt?.count > 0 {
                //1. loop through the attempts and adjust overlays and score to match
                for attempt in currentGame.attempt! {
                    if (attempt as! Attempt).countryToFind == (attempt as! Attempt).countryGuessed {
                        game["guessed"]![(attempt as! Attempt).countryToFind!] = (attempt as! Attempt).countryToFind
                        game["toPlay"]!.removeValueForKey((attempt as! Attempt).countryToFind!)
                        for overlay in worldMap.overlays {
                            if overlay.title! == (attempt as! Attempt).countryToFind {
                                worldMap.removeOverlay(overlay)
                                continue
                            }
                        }
                    } else if (attempt as! Attempt).revealed == true {
                        revealed += 1
                        game["toPlay"]!.removeValueForKey((attempt as! Attempt).countryToFind!)
                        for overlay in worldMap.overlays {
                            if overlay.title! == (attempt as! Attempt).countryToFind {
                                worldMap.removeOverlay(overlay)
                                continue
                            }
                        }
                    } else if (attempt as! Attempt).countryToFind != (attempt as! Attempt).countryGuessed {
                        misses += 1
                    }
                }
            }
        } else {
            //make a new game in core data and set as current
            currentGame = Game(continent: continent, mode: "practice", context: fetchedResultsController!.managedObjectContext)
            // use autosave to save it - else on exiting the core data entities are saved
        }
        print("games to play --->", game["toPlay"]!.count)
        //make label to show the user and pick random index to grab country name with
        makeQuestionLabel()
    }
    
    func makeQuestionLabel () {
        let index: Int = Int(arc4random_uniform(UInt32(game["toPlay"]!.count)))
        let countryToFind = Array(game["toPlay"]!.values)[index]
        toFind = countryToFind
        let screenSize = UIScreen.mainScreen().bounds.size
        label.frame = CGRectMake(0, 0 + 44, (screenSize.width + 5), 35)
        
        label.textAlignment = NSTextAlignment.Center
        label.text = "Find: \(countryToFind)"
        label.backgroundColor = UIColor(red: 0.3,green: 0.5,blue: 1,alpha: 1)
        label.textColor = UIColor.whiteColor()
        view.frame.origin.y = 44 * (-1)
        worldMap.addSubview(label)
    }
    
    func overlaySelected (gestureRecognizer: UIGestureRecognizer) {
        let pointTapped = gestureRecognizer.locationInView(worldMap)
        let tappedCoordinates = worldMap.convertPoint(pointTapped, toCoordinateFromView: worldMap)
        
        //loop through the countries in continent
        for (key, _) in coordinates {
            for landArea in coordinates[key]! {
                //each thing is a land area of coordinates
                if (Helpers.contains(landArea, selectedPoint: tappedCoordinates)) {
                    if (toFind == key) {
                        label.text = "Found!"
                        label.backgroundColor = UIColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0)
                        //save the attempt to coredata
                        let turn = Attempt(toFind: toFind, guessed: toFind, revealed: false, context: fetchedResultsController!.managedObjectContext)
                        turn.game = currentGame
                        currentGame.attempt?.setByAddingObject(turn)
                        Helpers.delay(0.7) {
                            self.setQuestionLabel()
                        }
                        //then we can delete country overlay from map as correct selection
                        updateMapOverlays(key)
                    } else {
                        //it was an incorrect guess, want to currently do nothing/change color/say wrong country on label
                        label.backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.5, alpha: 1.0)
                        misses += 1
                        //save attempt to core data
                        let turn = Attempt(toFind: toFind, guessed: key, revealed: false, context: fetchedResultsController!.managedObjectContext)
                        turn.game = currentGame
                        currentGame.attempt?.setByAddingObject(turn)
                        
                        Helpers.delay(0.7) {
                            self.label.text = "Find: \(self.toFind)"
                            self.label.backgroundColor = UIColor(red: 0.3,green: 0.5,blue: 1,alpha: 1)
                        }
                    }
                }
     
            }

        }
        
    }
    
    @IBAction func skip(sender: AnyObject) {
        setQuestionLabel()
    }
    
    //ask new question
    func setQuestionLabel () {
        if game["toPlay"]?.count > 0 {
            let index: Int = Int(arc4random_uniform(UInt32(game["toPlay"]!.count)))
            let randomVal = Array(game["toPlay"]!.values)[index]
            toFind = randomVal
            label.text = "Find: \(randomVal)"
            label.backgroundColor = UIColor(red: 0.3,green: 0.5,blue: 1,alpha: 1)
        } else {
            //nothing left to play - all countries have been guessed
            //push to score screen
            performSegueWithIdentifier("showScore", sender: nil)
            // save finish date to core data
            currentGame.finished_at = NSDate()
        }
        self.title = String("\(game["guessed"]!.count + revealed) / \(totalCountries)")
    }
    

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if segue.identifier == "showScore" {
            let controller = segue.destinationViewController as! ScoreViewController
            //get the id property on the annotation
            controller.score = game["guessed"]?.count
            controller.scoreTotal = totalCountries
            controller.revealed = revealed
            controller.misses = misses
        }
    }
    
    func updateMapOverlays(titleOfPolyToRemove: String) {
        for overlay: MKOverlay in worldMap.overlays {
            if overlay.title! == titleOfPolyToRemove {
                //remove references to this polygon
                //now need to get this polygon re-rendered - remove and then add?
                worldMap.removeOverlay(overlay)
                (overlay as! customPolygon).userGuessed = true
                worldMap.addOverlay(overlay)
                
                let annotation = MKPointAnnotation()
                annotation.coordinate = overlay.coordinate
                annotation.title = titleOfPolyToRemove
                worldMap.addAnnotation(annotation)
                //worldMap.removeOverlay(overlay)
            }
        }
        self.game["guessed"]![self.toFind] = self.toFind
        self.game["toPlay"]!.removeValueForKey(self.toFind)
    }

    func addBoundary(countryShape: Country) {
        var polygons = [MKPolygon]()
        //then need to loop through each boundary and make each a polygon and calculate the number of points
        for var landArea in (countryShape.boundary) {
            //let polygon = MKPolygon(coordinates: &landArea, count: landArea.count)
            let overlay = customPolygon(guessed: false, coords: landArea, numberOfPoints: landArea.count )
            overlay.title = countryShape.country
            polygons.append(overlay)
            worldMap.addOverlay(overlay)
            polygons.append(overlay)
        }
        createdPolygonOverlays[countryShape.country] = polygons
        coordinates[countryShape.country] = countryShape.boundary
    }

    
    @IBAction func showAll(sender: AnyObject) {
        //TODO: more functionality??
        //delete all overlays off the map
        for overlay: MKOverlay in worldMap.overlays {
            //TODO: show name of country
            worldMap.removeOverlay(overlay)
        }
        //delete the countries dictionary
        createdPolygonOverlays.removeAll()
        let region = Helpers.setZoomForContinent(continent)
        worldMap.setRegion(region, animated: true)
    }
    
    
    // this button shows the uncovers the current courty being asked
    @IBAction func reveal(sender: AnyObject) {
        // get the name of the country being asked
        for overlay in worldMap.overlays {
            if overlay.title!! == toFind {
                //remove reference to it in view
                worldMap.removeOverlay(overlay)
                // add reveal to core data
                let turn = Attempt(toFind: toFind, guessed: "", revealed: true, context: fetchedResultsController!.managedObjectContext)
                turn.game = currentGame
                currentGame.attempt?.setByAddingObject(turn)
                continue
            }
        }
        game["toPlay"]!.removeValueForKey(toFind)
        revealed += 1
        createdPolygonOverlays.removeValueForKey(toFind)
        coordinates.removeValueForKey(toFind)
        setQuestionLabel()
    }
    
    func returnToMainMenue () {
        navigationController?.popToRootViewControllerAnimated(true)
        currentGame.finished_at = NSDate()
        do {
            try fetchedResultsController!.managedObjectContext.save()
        } catch {
            print("error saving :(", error)
        }
    }
    
    // functions to deal with the restoring state
    override func encodeRestorableStateWithCoder(coder: NSCoder) {
        // save the continent as minimal source of data
        coder.encodeObject(continent as AnyObject, forKey: "continent")
        super.encodeRestorableStateWithCoder(coder)
    }
    
    override func decodeRestorableStateWithCoder(coder: NSCoder) {
        let data = coder.decodeObjectForKey("continent")
        continent = String(data!)
        restoreOccur = true
        super.decodeRestorableStateWithCoder(coder)
    }
    
    // once the app has loaded again work out what to show on the screen
    override func applicationFinishedRestoringState() {
        //grab the unfinished game and set to currrent game
        let moc = fetchedResultsController!.managedObjectContext
        let fetchRequest = NSFetchRequest(entityName: "Game")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "created_at", ascending: false)]
        
        var entities: [Game]
        do {
            entities = try moc.executeFetchRequest(fetchRequest) as! [Game]
        } catch {
            fatalError("Failed to fetch employees: \(error)")
        }
        // set the current game
        currentGame = entities[0]
    }
    
}

class customPolygon: MKPolygon {
    var userGuessed: Bool!
    convenience init(guessed: Bool, coords: [CLLocationCoordinate2D], numberOfPoints: Int) {
        self.init()
        var coords = coords
        self.init(coordinates: &coords, count: numberOfPoints)
        userGuessed = guessed
    }
}





