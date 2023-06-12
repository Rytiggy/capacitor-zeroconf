//
//  mCastBrowser.swift
//  mDNS_Browser
//
//  Created by Mark Robberts on 2021/07/22.
//  Refactored by Ryan Mason 2023/05/29.
//

import Capacitor
import Combine
import Network
import UIKit

class mCastBrowser: NSObject, ObservableObject, Identifiable {
  var firstRun = true
  struct objectOf: Hashable {
    var id: UUID? = UUID()
    var device: String = ""
    var IsIndexed: Int = 0
  }

  let serviceManager = ServiceManager()

  var browser: NWBrowser!
  var action: String = ""

  func scan(typeOf: String, domain: String, callback: @escaping (String, JSObject?) -> Void) {
    if browser != nil {
      browser.cancel()
    }
    ///Primarily use the Network Browser with the Bonjour descriptor
    let bonjourTCP: NWBrowser.Descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
      type: typeOf, domain: domain)

    let bonjourParms: NWParameters = NWParameters.init()
    bonjourParms.allowLocalEndpointReuse = true
    bonjourParms.acceptLocalOnly = true
    bonjourParms.allowFastOpen = true

    browser = NWBrowser(for: bonjourTCP, using: bonjourParms)

    browser.stateUpdateHandler = { newState in
      print("StateUpdateHandler", newState)
      switch newState {
      case .setup:
        self.action = "setup"
      case .ready:
        if self.firstRun {
          self.action = "loading"
          self.firstRun = false
        } else {
          self.action = "ready"
        }
      case .failed(let error):
        self.action = "failed \(error)"
        self.browser.cancel()
      case .cancelled:
        self.action = "cancelled"
      case .waiting(let result):
          self.action = "waiting \(result)"
      default:
        self.action = "unknown"
      }
      callback(self.action, nil)
    }

    browser.browseResultsChangedHandler = { (results, changes) in

      for change in changes {
          if case .added(let added) = change {
              // case service(name: String, type: String, domain: String, interface: NWInterface?)
              // This is the interesting part - the service has 4 parts - almost matching endpoint
              // because the endpoint has name Type, Domain, but then also metadata, and the last match with the service; interface
              // if case .service(let name, let type, let domain, let interface) = added.endpoint {
              // The real question should be, why not just create an array of endpoints, and keep that as reference?
              // But that we can do when connecting with endpoint name, because then it is best to refresh
              if case .service(let name,let one,let two, let three) = added.endpoint {
                  let txtRecord = self.getTxtRecord(result: added)
                  let service = Service(
                    domain: domain, type: typeOf, name: name, port: nil, hostName: added.endpoint,
                    ipv4Addresses: [], ipv6Addresses: [], txtRecord: txtRecord)
                  self.serviceManager.addService(service)
                  self.action = "added"
                  callback(self.action, self.jsonifyService(service))
                  // Resolve the IP address
                  do {
                      Task {
                          let address = try await self.resolveService(service: service, added: added)
                          self.action = "resolved"
                          let txtRecord = self.getTxtRecord(result: added)
                          let service = Service(
                            domain: domain, type: typeOf, name: name, port: address.port, hostName: added.endpoint,
                            ipv4Addresses: [address.ip], ipv6Addresses: [], txtRecord: txtRecord)
                          self.serviceManager.updateService(service)
                          callback(self.action, self.jsonifyService(service))
                          
                      }
                  }
              }
          }
          if case .removed(let removed) = change {
            if case .service(let name, _, _, _) = removed.endpoint {
              self.serviceManager.removeServiceByName(name)
              self.action = "removed"
              let txtRecord = self.getTxtRecord(result: removed)
              let serviceToRemove = Service(
                domain: domain, type: typeOf, name: name, port: 0, hostName: removed.endpoint,
                ipv4Addresses: [], ipv6Addresses: [], txtRecord: txtRecord)
         
              callback(self.action, self.jsonifyService(serviceToRemove))
            }
          }
        
      }
    }

    self.browser.start(queue: DispatchQueue.main)
  }

  // Parse the service so we can return it to capacitor
  func jsonifyService(_ service: Service) -> JSObject {
    let ipv4Addresses = service.ipv4Addresses
    var ipv6Addresses = service.ipv6Addresses

    if ipv6Addresses.count > 1 {
      let uniqueIPv6Addresses = Array(Set(ipv6Addresses))
      ipv6Addresses = uniqueIPv6Addresses
    }

      let hostName: String = "\(service.hostName)"


    let txtRecord: JSObject = service.txtRecord.reduce(into: [:]) { result, keyValue in
      result[keyValue.key] = keyValue.value as any JSValue
    }
      
    let port = Int(service.port ?? 000)
    let serviceDictionary: JSObject = [
      "domain": service.domain,
      "type": service.type,
      "name": service.name,
      "port": port,
      "hostname": hostName,
      "ipv4Addresses": ipv4Addresses,
      "ipv6Addresses": ipv6Addresses,
      "txtRecord": txtRecord,
    ]

    return serviceDictionary
  }

  // Resolve a services endpoint to its IP
    
    func resolveService(service: Service, added: NWBrowser.Result) async throws -> (ip: String, port: UInt16){
    return try await withCheckedThrowingContinuation { continuation in
      // Resolve the address of the service
      // https://stackoverflow.com/questions/60579798/how-to-resolve-addresses-and-port-information-from-an-nwendpoint-service-enum-ca/68722404#68722404
      let connection = NWConnection(to: added.endpoint, using: .tcp)
      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          if let innerEndpoint = connection.currentPath?.remoteEndpoint,
            case .hostPort(let host, let port) = innerEndpoint
          {
            var ipAddress = "\(host)"
            ipAddress = ipAddress.replacingOccurrences(
              of: "%\\w+", with: "", options: .regularExpression)
            self.action = "resolved"
            print("port:" ,Int(port.rawValue), port)
            continuation.resume(returning: (ip:ipAddress, port: port.rawValue))

          }
        default:
          break
        }
      }
      connection.start(queue: DispatchQueue.main)
    }
  }

  func getTxtRecord(result: NWBrowser.Result) -> [String: String] {
    if case NWBrowser.Result.Metadata.bonjour(let txtRecord) = result.metadata {
      return txtRecord.dictionary
    }

    return [:]  // Return an empty dictionary if the condition is not met
  }
}
