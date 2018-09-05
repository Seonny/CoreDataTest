//
//  ViewController.swift
//  CoreDataTest
//
//  Created by sunhy78 on 2018. 9. 3..
//  Copyright © 2018년 sunhy78. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var viewContext: NSManagedObjectContext {
        return appDelegate.persistentContainer.viewContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setupDataToTest()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func setupDataToTest() {
        // Save a row to test
        let saveContext = appDelegate.persistentContainer.newBackgroundContext()
        saveContext.performAndWait { [weak self] in
            guard let strongSelf = self else { return }

            if let results = fetchAllData(context: saveContext) {
                print(results)

                results.forEach({
                    saveContext.delete($0)
                })

                do {
                    try saveContext.save()
                }
                catch {
                    print("Deletion all failed")
                }
            }

            if let entity = strongSelf.fetchData(context: saveContext) {
                entity.val1 = "NONE"
            }
            else {
                let entity = Entity1(context: saveContext)
                entity.val1 = "NONE"
                entity.keyword = "onlyMe"
            }

            if let newEntity = strongSelf.fetchNewData(context: saveContext) {
                newEntity.val1 = "No person wins"
            }
            else {
                let newEntity = Entity1(context: saveContext)
                newEntity.keyword = "NewEntityContext"
                newEntity.val1 = "NO person wins"
            }

            do {
                try saveContext.save()
            }
            catch {
                print("Init save error")
            }
        }
    }
}

extension ViewController {
    private func fetchAllData(context: NSManagedObjectContext) -> [Entity1]? {
        let fetchAllRequest = NSFetchRequest<Entity1>(entityName: "Entity1")
        if let results = try? context.fetch(fetchAllRequest) {
            return results
        }
        else {
            return nil
        }
    }

    private func fetchData(context: NSManagedObjectContext) -> Entity1? {
        let request = NSFetchRequest<Entity1>(entityName: "Entity1")
        let predicate = NSPredicate(format: "keyword = %@", argumentArray: ["onlyMe"])
        request.predicate = predicate

        return fetch(request: request, context: context)
    }

    private func fetchNewData(context: NSManagedObjectContext) -> Entity1? {
        let request = NSFetchRequest<Entity1>(entityName: "Entity1")
        let predicate = NSPredicate(format: "keyword = %@", argumentArray: ["NewEntityContext"])
        request.predicate = predicate

        return fetch(request: request, context: context)
    }

    private func fetch(request: NSFetchRequest<Entity1>, context: NSManagedObjectContext) -> Entity1? {
        do {
            let results = try context.fetch(request)
            return results.first
        }
        catch {
            print(error)
            return nil
        }
    }
}

extension ViewController {

    private func testSaveForParent(context childContext: NSManagedObjectContext, autoMergeFromParent: Bool = true) {
        setupDataToTest()

        let parentContext = appDelegate.persistentContainer.newBackgroundContext()
        childContext.parent = parentContext
        childContext.automaticallyMergesChangesFromParent = autoMergeFromParent

        var chagnedValueInNewContextToPS: String = "N/A"

        var parentEntity: Entity1 = Entity1(context: parentContext)
        parentContext.performAndWait {
            parentEntity = fetchData(context: parentContext)!
            print("\n################################################################")
            print("PARENT: will test with init value: \(parentEntity.val1!)")
        }

        var childEntity: Entity1 = Entity1(context: childContext)
        childContext.performAndWait {
            print("\n################################################################")
            childEntity = fetchData(context: childContext)!
            print("CHILD: will test with init value: \(childEntity.val1!)")
        }

        //////////////////////////////////////////

        parentContext.performAndWait { [weak self] in
            print("\n################################################################")
            parentEntity.val1 = "PARENT_FIRST"
            print("PARENT: will chagne")
            chagnedValueInNewContextToPS = parentEntity.val1!
            print("PARENT: did chagne to \(parentEntity.val1!)")

            do {
                // to test automaticallyMergesChangesFromParent
                print("PARENT: will save to test automaticallyMergesChangesFromParent \(parentEntity.val1!)")
                try parentContext.save()
                print("PARENT: did save to test automaticallyMergesChangesFromParent: \(self!.fetchData(context: parentContext)!.val1!)")
            }
            catch {
                print("PARENT: error: saving in parent: \(error)")
            }
        }

        childContext.performAndWait {
            print("\n################################################################")
            print("CHILD: This had fetched the value in bgContext at first: \(childEntity.val1!)")
            print("""
                CHILD: - checking automaticallyMergesChangesFromParent:
                       - parent value \(chagnedValueInNewContextToPS)
                       - result \(chagnedValueInNewContextToPS == childEntity.val1!)
                """)
            print("\n=======================================")
        }

        ////////////////////////////////

        childContext.perform { [weak self] in
            guard let strongSelf = self else {
                print("CHILD: cannot pring results")
                return
            }

            do {
                print("CHILD: will change")
                childEntity.val1 = "CHILD_FIRST"
                print("CHILD: did change to \(childEntity.val1!)")
                print("CHILD: will save \(childEntity.val1!)")
                try childContext.save()
                let childSavedValue = strongSelf.fetchData(context: childContext)!.val1!
                print("CHILD: did save \(childSavedValue)")


                parentContext.performAndWait {
                    print("""
                            - PARENT: Merge from CHILD
                            - Child(\(childSavedValue)) == Parent(\(parentEntity.val1!)): \
                        \(childSavedValue == parentEntity.val1!)
                            * NOT CALLED save() of PARENT
                        """)
                }
            }
            catch {
                print("CHILD: error: saving in bg: \(error)")
            }

            DispatchQueue.main.sync { [unowned strongSelf] in
                let viewContext = strongSelf.appDelegate.persistentContainer.viewContext
                let entity = strongSelf.fetchData(context: viewContext)!
                print("CHILD MAIN CONTEXT RESULT \(entity.val1!)")
            }
        }

        parentContext.perform { [weak self] in
            guard let strongSelf = self else {
                print("PARENT: cannot pring results")
                return
            }

            do {

                print("PARENT: will chagne")
                parentEntity.val1 = "PARENT_SECOND"
                print("PARENT: did chagne to \(parentEntity.val1!)")
                print("PARENT: will save \(parentEntity.val1!)")
                try parentContext.save()
                print("PARENT: did save \(strongSelf.fetchData(context: parentContext)!.val1!)")
            }
            catch {
                print("PARENT: error: saving in parent: \(error)")
            }

            DispatchQueue.main.sync { [unowned strongSelf] in
                let viewContext = strongSelf.appDelegate.persistentContainer.viewContext
                let entity = strongSelf.fetchData(context: viewContext)!
                print("PARENT MAIN CONTEXT RESULT \(entity.val1!)")
            }
        }
    }

    @IBAction func saveErrorPolicyNoAuto() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("#Parent: Error Policy with NO automaticallyMergesChangesFromParent")
        testSaveForParent(context: appDelegate.backgroundContextErrorPolicy, autoMergeFromParent: false)
    }

    @IBAction func saveStoreTrumpPolicyNoAuto() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("#Parent: Store Trump Policy with NO automaticallyMergesChangesFromParent")
        testSaveForParent(context: appDelegate.backgroundContextStoreTrumpPolicy, autoMergeFromParent: false)
    }

    @IBAction func saveObjectTrumpPolicyNoAuto() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("#Parent: Object Trump Policy with NO automaticallyMergesChangesFromParent")
        testSaveForParent(context: appDelegate.backgroundContextObjectTrumpPolicy, autoMergeFromParent: false)
    }

    @IBAction func saveErrorPolicy() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("#Parent: Error Policy with automaticallyMergesChangesFromParent")
        testSaveForParent(context: appDelegate.backgroundContextErrorPolicy)
    }

    @IBAction func saveStoreTrumpPolicy() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("#Parent: Store Trump Policy with automaticallyMergesChangesFromParent")
        testSaveForParent(context: appDelegate.backgroundContextStoreTrumpPolicy)
    }

    @IBAction func saveObjectTrumpPolicy() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("#Parent: Object Trump Policy with automaticallyMergesChangesFromParent")
        testSaveForParent(context: appDelegate.backgroundContextObjectTrumpPolicy)
    }
}

extension ViewController {

    private func testSaveForPS(mergePolicy: Any) {
        setupDataToTest()

        let contextA = appDelegate.persistentContainer.newBackgroundContext()
        contextA.mergePolicy = mergePolicy


        let contextB = appDelegate.persistentContainer.newBackgroundContext()
        contextB.mergePolicy = mergePolicy

        let contextC = appDelegate.persistentContainer.newBackgroundContext()
        contextC.mergePolicy = mergePolicy

        var entityContextA = Entity1(context: contextA)
        var newEntityContextA = Entity1(context: contextA)
        contextA.performAndWait {
            entityContextA = fetchData(context: contextA)!
            newEntityContextA = fetchNewData(context: contextA)!
            print("CONTEXT A: will test with \(entityContextA.val1!) and  \(newEntityContextA.val1!)")
        }

        var entityContextB = Entity1(context: contextB)
        var newEntityContextB = Entity1(context: contextB)
        contextB.performAndWait {
            entityContextB = fetchData(context: contextB)!
            newEntityContextB = fetchNewData(context: contextB)!
            print("CONTEXT B: will test with \(entityContextB.val1!) and  \(newEntityContextB.val1!)")

        }

        var entityContextC = Entity1(context: contextC)
        var newEntityContextC = Entity1(context: contextC)
        contextC.performAndWait {
            entityContextC = fetchData(context: contextC)!
            newEntityContextC = fetchNewData(context: contextC)!
            print("CONTEXT C: will test with \(entityContextC.val1!) and  \(newEntityContextC.val1!)")
        }

        contextA.perform { [unowned self] in
            print("CONTEXT A: will change")
            entityContextA.val1 = "CONTEXT A FIRST"
            print("CONTEXT A: did chagne to \(entityContextA.val1!)")

            newEntityContextA.val1 = "A person wins"
            print("CONTEXT A: newEntity did update \(newEntityContextA)")

            do {
                print("CONTEXT A: will save")
                try contextA.save()
                print("CONTEXT A: did save")

                DispatchQueue.main.sync { [unowned self] in
                    let viewContext = self.appDelegate.persistentContainer.viewContext
                    let entity = self.fetchData(context: viewContext)!
                    print("CONTEXT A RESULT in MAIN CONTEXT \(entity.val1!)")

                    if let newEntity = self.fetchNewData(context: viewContext) {
                        print("CONTEXT A new data RESULT \(newEntity.val1!)")
                    }
                    else {
                        print("CONTEXT A new data is not inserted")
                    }
                }
            }
            catch {
                print("CONTEXT A: error \(error)")
            }
        }

        contextB.perform { [unowned self] in
            print("CONTEXT B: will change")
            entityContextB.val1 = "CONTEXT B FIRST"
            print("CONTEXT B: did chagne to \(entityContextB.val1!)")

            newEntityContextB.val1 = "B person wins"
            print("CONTEXT B: newEntity did update \(newEntityContextB)")

            do {
                print("CONTEXT B: will save")
                try contextB.save()
                print("CONTEXT B: did save")

                DispatchQueue.main.sync { [unowned self] in
                    let viewContext = self.appDelegate.persistentContainer.viewContext
                    let entity = self.fetchData(context: viewContext)!
                    print("CONTEXT B RESULT in MAIN CONTEXT \(entity.val1!)")

                    if let newEntity = self.fetchNewData(context: viewContext) {
                        print("CONTEXT B new data RESULT \(newEntity.val1!)")
                    }
                    else {
                        print("CONTEXT B new data is not inserted")
                    }
                }
            }
            catch {
                print("CONTEXT B: error \(error)")
            }
        }

        contextC.perform { [unowned self] in
            print("CONTEXT C: will change")
            entityContextC.val1 = "CONTEXT C FIRST"
            print("CONTEXT C: did chagne to \(entityContextC.val1!)")

            newEntityContextC.val1 = "C person wins"
            print("CONTEXT C: newEntity did update \(newEntityContextC)")

            do {
                print("CONTEXT C: will save")
                try contextC.save()
                print("CONTEXT C: did save")

                DispatchQueue.main.sync { [unowned self] in
                    let viewContext = self.appDelegate.persistentContainer.viewContext
                    let entity = self.fetchData(context: viewContext)!
                    print("CONTEXT C RESULT in MAIN CONTEXT \(entity.val1!)")

                    if let newEntity = self.fetchNewData(context: viewContext) {
                        print("CONTEXT C new data RESULT \(newEntity.val1!)")
                    }
                    else {
                        print("CONTEXT C new data is not inserted")
                    }
                }
            }
            catch {
                print("CONTEXT C: error \(error)")
            }
        }
    }


    @IBAction func saveNewBGErrorPolicy() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("&saveNewBGErrorPolicy")
        testSaveForPS(mergePolicy: NSErrorMergePolicy )
    }

    @IBAction func saveNewBGStoreTrumpPolicy() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("^saveNewBGStoreTrumpPolicy")
        testSaveForPS(mergePolicy: NSMergeByPropertyStoreTrumpMergePolicy)
    }

    @IBAction func saveNewBGObjectTrumpPolicy() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("*saveNewBGObjectTrumpPolicy")
        testSaveForPS(mergePolicy: NSMergeByPropertyObjectTrumpMergePolicy)
    }

    @IBAction func saveNewBGOverWrittenPolicy() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("*saveNewBGOverWrittenPolicy")
        testSaveForPS(mergePolicy: NSOverwriteMergePolicy)
    }

    @IBAction func saveNewBGRollbackPolicy() {
        print("\r\n^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
        print("*saveNewBGRollbackPolicy")
        testSaveForPS(mergePolicy: NSRollbackMergePolicy)
    }

}

