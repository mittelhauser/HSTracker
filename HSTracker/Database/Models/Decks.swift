//
//  Decks.swift
//  HSTracker
//
//  Created by Benjamin Michotte on 17/04/16.
//  Copyright © 2016 Benjamin Michotte. All rights reserved.
//

import Foundation
import CleanroomLogger
import Unbox
import Wrap

final class Decks {
    static let instance = Decks()

    private var _decks = [String: Deck]()

    private var savePath: String? {
        if let path = Settings.instance.deckPath {
            return "\(path)/decks.json"
        }
        return nil
    }

    init() {
        loadDecks()
    }

    private func loadDecks() {
        // backup decks.json
        if let jsonFile = savePath {
            if NSFileManager.defaultManager().fileExistsAtPath(jsonFile) {
                do {
                    try NSFileManager.defaultManager()
                        .copyItemAtPath(jsonFile, toPath: "\(jsonFile).bkp")
                } catch {}
            }
        }

        // load decks
        if let jsonFile = savePath, jsonData = NSData(contentsOfFile: jsonFile) {
            Log.verbose?.message("json file : \(jsonFile)")
            do {
                if let decks: [String: [String: AnyObject]] =
                    try NSJSONSerialization.JSONObjectWithData(jsonData,
                                                               options: .AllowFragments)
                        as? [String: [String: AnyObject]] {

                    for (_, _deck) in decks {

                        let deck: Deck = try Unbox(_deck)
                        if deck.isValid() {
                            _decks[deck.deckId] = deck
                        }
                    }
                }
            } catch {
            }
        }
    }

    func resetDecks() {
        loadDecks()
        NSNotificationCenter.defaultCenter().postNotificationName("reload_decks", object: nil)
    }

    func decks() -> [Deck] {
        return _decks.map { $0.1 }
    }

    func add(deck: Deck) {
        deck.creationDate = NSDate()
        _decks[deck.deckId] = deck
        save()
    }

    func update(deck: Deck) {
        _decks[deck.deckId] = deck
        save()
    }

    func remove(deck: Deck) {
        _decks[deck.deckId] = nil
        save()
    }

    private var savedCountRequest = 0
    internal func save() {
        savedCountRequest += 1
        let when = dispatch_time(DISPATCH_TIME_NOW, Int64(100 * Double(NSEC_PER_MSEC)))
        let queue = dispatch_get_main_queue()
        dispatch_after(when, queue) {
            self.savedCountRequest -= 1
            if self.savedCountRequest > 0 {
                return
            }

            var jsonDecks = [String: [String: AnyObject]]()
            for (deckId, deck) in self._decks {
                do {
                    jsonDecks[deckId] = try Wrap(deck)
                } catch {}
            }
            if let jsonFile = self.savePath {
                do {
                    let data = try NSJSONSerialization.dataWithJSONObject(jsonDecks,
                                                                          options: .PrettyPrinted)
                    data.writeToFile(jsonFile, atomically: true)
                } catch {
                    // TODO error
                }
            }

            NSNotificationCenter.defaultCenter().postNotificationName("reload_decks", object: nil)
        }
    }

    func byId(id: String) -> Deck? {
        return decks().filter({ $0.deckId == id }).first
    }
}
