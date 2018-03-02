//
//  PlayListViewController.swift
//  drivecamera
//
//  Created by Kazuo Tsubaki on 2018/03/01.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import UIKit
import AVFoundation

class PlayListViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var videoFiles: [URL] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        definesPresentationContext = true
        listVideoFiles()
    }

    @IBAction func closePlayList(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    private func listVideoFiles() -> Void {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions.skipsSubdirectoryDescendants)
            for fileURL in fileURLs {
                if fileURL.lastPathComponent.hasPrefix("dc-") && fileURL.lastPathComponent.hasSuffix(".mp4") {
                    videoFiles.append(fileURL)
                }
            }
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
    }
}

extension PlayListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
            let url = videoFiles[indexPath.row]
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Error removing ", url)
            }
            videoFiles.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let viewController = storyboard?.instantiateViewController(withIdentifier: "player") as! PlayerViewController
        let url = videoFiles[indexPath.row]
        viewController.setAsset(asset:AVAsset(url:url))
        let nav = UINavigationController(rootViewController: viewController)
        present(nav, animated: true, completion: nil)
    }
}

extension PlayListViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videoFiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PlayListCell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! PlayListCell
        let url = videoFiles[indexPath.row]
        cell.setURL(url: url)
        return cell
    }
    
}
