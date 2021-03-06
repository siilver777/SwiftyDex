//
//  PokemonViewController.swift
//  PokeStats
//
//  Created by Jason Pierna on 12/12/2016.
//  Copyright © 2016 Jason Pierna. All rights reserved.
//

import UIKit
import AVFoundation
import CoreSpotlight
import MobileCoreServices

import Alamofire
import SwiftyJSON
import FBSDKShareKit

class PokemonViewController: UIViewController {
    
    @IBOutlet weak var artworkImageView: UIImageView!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var firstTypeImageView: UIImageView!
    @IBOutlet weak var secondTypeImageView: UIImageView!
    
    @IBOutlet weak var heightLabel: UILabel!
    @IBOutlet weak var weightLabel: UILabel!
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet weak var descriptionButton: UIButton!
    
    @IBOutlet weak var pvLabel: UILabel!
    @IBOutlet weak var atkLabel: UILabel!
    @IBOutlet weak var defLabel: UILabel!
    @IBOutlet weak var atkSpeLabel: UILabel!
    @IBOutlet weak var defSpeLabel: UILabel!
    @IBOutlet weak var vitLabel: UILabel!
    
    @IBOutlet weak var favoriteButton: UIButton!
    
    @IBOutlet weak var firstTypeAlignmentConstraint: NSLayoutConstraint!
    @IBOutlet weak var secondTypeWidthConstraint: NSLayoutConstraint!
    
    
    var pokemon: Pokemon!
    var audioPlayer: AVAudioPlayer?
    
    lazy var synthesizer: AVSpeechSynthesizer = {
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        return synthesizer
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadUI()
        
        // Gesture Recognizer for sound
        artworkImageView.isUserInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: self, action: #selector(playSound))
        artworkImageView.addGestureRecognizer(gesture)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func favorite(sender: UIButton?) {
        
        if let context = DataManager.shared.context {
            pokemon.favorite = !pokemon.favorite
            
            do {
                try context.save()
                
                if pokemon.favorite {
                    favoriteButton.setImage(#imageLiteral(resourceName: "favoriteFilled"), for: .normal)
                    index()
                }
                else {
                    favoriteButton.setImage(#imageLiteral(resourceName: "favoriteEmpty"), for: .normal)
                    deindex()
                }
                
            }
            catch {
                print(error)
            }
        }
    }
    
    @IBAction func readDescription() {
        if synthesizer.isSpeaking {
            if synthesizer.isPaused {
                synthesizer.continueSpeaking()
            }
            else {
                synthesizer.pauseSpeaking(at: .immediate)
            }
        }
        else {
            let utterance = AVSpeechUtterance(string: pokemon.pokedexDescription)
            
            utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
            utterance.rate = 0.55
            
            synthesizer.speak(utterance)
        }
    }
    
    @IBAction func share() {
        if FBSDKAccessToken.current() != nil {
            let content = FBSDKShareLinkContent()
            
            if let url = "http://www.pokepedia.fr/index.php/\(pokemon.name)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                content.contentURL = URL(string: url)
                FBSDKShareDialog.show(from: self, with: content, delegate: nil)
            }
        }
        else {
            let alert = UIAlertController(title: "LOGIN_FACEBOOK_ALERT_TITLE".localized, message: "LOGIN_FACEBOOK_ALERT_DESC".localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    func loadUI() {
        // Navigation bar
        navigationItem.title = pokemon.name
        
        // Main information
        var region = ""
        
        if pokemon.number.intValue <= 151 {
            region = "REGION_1".localized
        }
        else if pokemon.number.intValue <= 251 {
            region = "REGION_2".localized
        }
        else if pokemon.number.intValue <= 386 {
            region = "REGION_3".localized
        }
        else if pokemon.number.intValue <= 493 {
            region = "REGION_4".localized
        }
        else if pokemon.number.intValue <= 649 {
            region = "REGION_5".localized
        }
        else if pokemon.number.intValue <= 721 {
            region = "REGION_6".localized
        }
        else {
            region = "REGION_7".localized
        }
        
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumIntegerDigits = 3
        numberFormatter.maximumIntegerDigits = 3
        numberFormatter.allowsFloats = false
        
        if let number = numberFormatter.string(from: pokemon.number) {
            numberLabel.text = region + " #" + number
        }
    
        firstTypeImageView.image = UIImage(named: "type\(pokemon.type1.rawValue)")
        if let type2 = pokemon.type2 {
            secondTypeImageView.image = UIImage(named: "type\(type2.rawValue)")
        }
        else {
            secondTypeImageView.image = nil
            secondTypeWidthConstraint.constant = 0
            firstTypeAlignmentConstraint.constant = 0
        }
        heightLabel.text = String(pokemon.height) + "m"
        weightLabel.text = String(pokemon.weight) + "kg"
        descriptionTextView.text = pokemon.pokedexDescription
        
        // Stats
        
        pvLabel.text = String(pokemon.stats.pv)
        atkLabel.text = String(pokemon.stats.atk)
        defLabel.text = String(pokemon.stats.def)
        atkSpeLabel.text = String(pokemon.stats.atkspe)
        defSpeLabel.text = String(pokemon.stats.defspe)
        vitLabel.text = String(pokemon.stats.vit)
        
        // Favorite button state
        
        if pokemon.favorite {
            favoriteButton.setImage(#imageLiteral(resourceName: "favoriteFilled"), for: .normal)
        }
        else {
            favoriteButton.setImage(#imageLiteral(resourceName: "favoriteEmpty"), for: .normal)
        }
        
        // Artwork
        
        if let artworkPath = FileManager.documentsURL(childPath: "artwork_\(self.pokemon.number).png") {
            if FileManager.default.fileExists(atPath: artworkPath.path) {
                // Load from disk
                let artwork = UIImage(contentsOfFile: artworkPath.path)
                self.artworkImageView.image = artwork
            }
            else {
                // Download and store
                if let artworkUrl = URL(string: API.artwork(no: self.pokemon.number.intValue)) {
                    let artworkQueue = DispatchQueue(label: "artwork")
                    artworkQueue.async {
                        if let data = try? Data(contentsOf: artworkUrl),
                            let artwork = UIImage(data: data) {
                            try? data.write(to: artworkPath, options: .atomic)
                            
                            DispatchQueue.main.async {
                                self.artworkImageView.image = artwork
                            }
                        }
                    }
                }
            }
        }
        
        // Sound
        
        let soundQueue = DispatchQueue(label: "sound")
        soundQueue.async {
            if let soundPath = FileManager.documentsURL(childPath: "sound_\(self.pokemon.number).mp3") {
                if FileManager.default.fileExists(atPath: soundPath.path) {
                    // Load from disk
                    self.audioPlayer = try? AVAudioPlayer(contentsOf: soundPath)
                }
                else {
                    // Download
                    if let soundUrl = URL(string: API.sound(no: self.pokemon.number.intValue)),
                        let data = try? Data(contentsOf: soundUrl) {
                        // Save on disk
                        try? data.write(to: soundPath, options: .atomic)
                        
                        // Load the file in the player
                        self.audioPlayer = try? AVAudioPlayer(data: data)
                    }
                }
            }
        }
    }
    
    func playSound() {
        if let audioPlayer = audioPlayer {
            audioPlayer.play()
            
            // Animate the Pokemon artwork
            artworkImageView.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.4,
                           delay: 0.0,
                           usingSpringWithDamping: 0.2,
                           initialSpringVelocity: 1.0,
                           options: .curveEaseInOut, animations: {
                self.artworkImageView.transform = .identity
            })
        }
    }
    
    func index() {
        // Creating Indexable item in CoreSpotlight
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        attributeSet.title = pokemon.name
        attributeSet.contentDescription = pokemon.pokedexDescription
        attributeSet.thumbnailURL = FileManager.documentsURL(childPath: "artwork_\(pokemon.number).png")
        
        let item = CSSearchableItem(uniqueIdentifier: pokemon.name, domainIdentifier: "com.jpierna.SwiftyDex", attributeSet: attributeSet)
        item.expirationDate = Date.distantFuture
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Indexing error: \(error)")
            }
            else {
                print("Search item successfully indexed!")
            }
        }
    }
    
    func deindex() {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [pokemon.name]) { error in
            if let error = error {
                print("Deindexing error: \(error)")
            }
            else {
                print("Search item successfully deindexed!")
            }
        }
    }
}

extension PokemonViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        descriptionButton.setImage(#imageLiteral(resourceName: "pauseButton"), for: .normal)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        descriptionButton.setImage(#imageLiteral(resourceName: "playButton"), for: .normal)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        descriptionButton.setImage(#imageLiteral(resourceName: "playButton"), for: .normal)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        descriptionButton.setImage(#imageLiteral(resourceName: "pauseButton"), for: .normal)
    }
}
