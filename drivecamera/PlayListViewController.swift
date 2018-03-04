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
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var viewSwitchSegmentedControl: UISegmentedControl!
    
    var videoFiles: [URL] = []
    var logFiles: [URL] = []
    var filename: FilenameUtil = FilenameUtil()

    override func viewDidLoad() {
        super.viewDidLoad()
        definesPresentationContext = true
        closeButton.layer.masksToBounds = true
        closeButton.layer.cornerRadius = 25
        closeButton.layer.opacity = 0.4
        closeButton.backgroundColor = UIColor.black
        closeButton.tintColor = UIColor.white
        viewSwitchSegmentedControl.selectedSegmentIndex = 0
        showVideos()
    }

    private func showVideos() {
        listVideoFiles()
        tableView.reloadData()
    }
    
    private func showLogs() {
        listLogFiles()
        tableView.reloadData()
    }
    
    @IBAction func closePlayList(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func viewSwitchChanged(_ sender: Any) {
        switch viewSwitchSegmentedControl.selectedSegmentIndex {
        case 0:
            showVideos()
            break
        case 1:
            showLogs()
            break
        default:
            showVideos()
            break
        }
    }
    
    private func listVideoFiles() -> Void {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        videoFiles = []
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions.skipsSubdirectoryDescendants)
            for fileURL in fileURLs {
                if fileURL.lastPathComponent.hasSuffix(".mp4") {
                    videoFiles.append(fileURL)
                }
            }
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
    }
    
    private func listLogFiles() -> Void {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logFiles = []
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions.skipsSubdirectoryDescendants)
            for fileURL in fileURLs {
                if fileURL.lastPathComponent.hasSuffix(".csv") {
                    logFiles.append(fileURL)
                }
            }
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
    }
}

extension PlayListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if viewSwitchSegmentedControl.selectedSegmentIndex == 0 {
            return 64
        } else {
            return 40
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
            if viewSwitchSegmentedControl.selectedSegmentIndex == 0 {
                let url = videoFiles[indexPath.row]
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    print("Error removing ", url)
                }
                videoFiles.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
            } else {
                let url = logFiles[indexPath.row]
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    print("Error removing", url)
                }
                logFiles.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if viewSwitchSegmentedControl.selectedSegmentIndex == 0 {
            let viewController = storyboard?.instantiateViewController(withIdentifier: "player") as! PlayerViewController
            let url = videoFiles[indexPath.row]
            viewController.setVideoURL(url: url)
            let nav = UINavigationController(rootViewController: viewController)
            present(nav, animated: true, completion: nil)
        } else {
            let viewController = storyboard?.instantiateViewController(withIdentifier: "map") as! LogMapViewController
            let url = logFiles[indexPath.row]
            viewController.setLogURL(url: url)
            let nav = UINavigationController(rootViewController: viewController)
            present(nav, animated: true, completion: nil)
        }
    }
}

extension PlayListViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if viewSwitchSegmentedControl.selectedSegmentIndex == 0 {
            return videoFiles.count
        } else {
            return logFiles.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if viewSwitchSegmentedControl.selectedSegmentIndex == 0 {
            let cell: PlayListCell = tableView.dequeueReusableCell(withIdentifier: "VideoCell", for: indexPath) as! PlayListCell
            let url = videoFiles[indexPath.row]
            cell.setURL(url: url)
            return cell
        } else {
            let cell: UITableViewCell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "LogCell")
            let name = logFiles[indexPath.row].lastPathComponent
            let fn = String(name[name.index(name.startIndex, offsetBy: 0)...name.index(name.endIndex, offsetBy: -5)])
            let ts = filename.date(fromFilename: fn)
            cell.textLabel?.text = filename.timestamp(from: ts)
            return cell
        }
    }
    
}
