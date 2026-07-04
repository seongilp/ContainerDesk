import XCTest
@testable import ContainerDesk

final class DecodingTests: XCTestCase {

    func testDecodeContainerList() throws {
        let json = """
        [{"configuration":{"id":"test-web","creationDate":"2026-07-04T04:07:35Z",
        "image":{"reference":"docker.io/library/alpine:latest","descriptor":{"digest":"sha256:abc","size":9218}},
        "initProcess":{"executable":"sleep","arguments":["300"],"workingDirectory":"/"},
        "labels":{},"mounts":[],"networks":[{"network":"default"}],
        "publishedPorts":[],"resources":{"cpus":4,"memoryInBytes":1073741824},
        "platform":{"architecture":"arm64","os":"linux"}},
        "id":"test-web",
        "status":{"state":"running","startedDate":"2026-07-04T04:07:37Z",
        "networks":[{"hostname":"test-web","ipv4Address":"192.168.64.2/24","network":"default"}]}}]
        """
        let records = try JSONDecoder().decode([ContainerRecord].self, from: Data(json.utf8))
        XCTAssertEqual(records.count, 1)
        let container = records[0]
        XCTAssertEqual(container.id, "test-web")
        XCTAssertEqual(container.state, .running)
        XCTAssertTrue(container.state.isRunning)
        XCTAssertEqual(container.shortImage, "alpine:latest")
        XCTAssertEqual(container.ipv4Address, "192.168.64.2")
        XCTAssertEqual(container.command, "sleep 300")
    }

    func testDecodeStoppedContainerAndMissingStatus() throws {
        let json = """
        [{"configuration":{"id":"a"},"id":"a","status":{"state":"stopped"}},
         {"configuration":{"id":"b"},"id":"b"}]
        """
        let records = try JSONDecoder().decode([ContainerRecord].self, from: Data(json.utf8))
        XCTAssertEqual(records[0].state, .stopped)
        XCTAssertEqual(records[1].state, .unknown)
        XCTAssertNil(records[1].ipv4Address)
    }

    func testDecodeImageList() throws {
        let json = """
        [{"configuration":{"creationDate":"2026-06-16T00:00:15Z",
        "descriptor":{"digest":"sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b",
        "mediaType":"application/vnd.oci.image.index.v1+json","size":9218},
        "name":"docker.io/library/alpine:latest"},
        "id":"28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b",
        "variants":[
          {"digest":"sha256:aaa","platform":{"architecture":"arm64","os":"linux"},"size":4000000},
          {"digest":"sha256:bbb","platform":{"architecture":"amd64","os":"linux"},"size":3848024}
        ]}]
        """
        let images = try JSONDecoder().decode([ImageRecord].self, from: Data(json.utf8))
        XCTAssertEqual(images.count, 1)
        let image = images[0]
        XCTAssertEqual(image.reference, "docker.io/library/alpine:latest")
        XCTAssertEqual(image.repositoryAndTag.repository, "docker.io/library/alpine")
        XCTAssertEqual(image.repositoryAndTag.tag, "latest")
        XCTAssertEqual(image.shortRepository, "alpine")
        XCTAssertEqual(image.shortDigest, "28bd5fe8b56d")
        #if arch(arm64)
        XCTAssertEqual(image.displaySize, 4000000)
        #endif
    }

    func testRepositoryWithPortAndNoTag() {
        let image = ImageRecord(
            id: "x",
            configuration: .init(
                name: "localhost:5000/myimage",
                creationDate: nil,
                descriptor: nil
            ),
            variants: nil
        )
        XCTAssertEqual(image.repositoryAndTag.repository, "localhost:5000/myimage")
        XCTAssertEqual(image.repositoryAndTag.tag, "latest")
    }

    func testDecodeVolumeList() throws {
        let json = """
        [{"configuration":{"creationDate":"2026-07-04T04:08:20Z","driver":"local",
        "format":"ext4","labels":{},"name":"testvol","options":{},
        "sizeInBytes":549755813888,"source":"/tmp/volume.img"},"id":"testvol"}]
        """
        let volumes = try JSONDecoder().decode([VolumeRecord].self, from: Data(json.utf8))
        XCTAssertEqual(volumes[0].name, "testvol")
        XCTAssertEqual(volumes[0].configuration.sizeInBytes, 549755813888)
    }

    func testDecodeNetworkList() throws {
        let json = """
        [{"configuration":{"creationDate":"1970-01-01T00:00:00Z",
        "labels":{"com.apple.container.resource.role":"builtin"},"mode":"nat",
        "name":"default","options":{},"plugin":"container-network-vmnet"},
        "id":"default",
        "status":{"ipv4Gateway":"192.168.64.1","ipv4Subnet":"192.168.64.0/24",
        "ipv6Subnet":"fd59:cd00:9304:1fc4::/64"}}]
        """
        let networks = try JSONDecoder().decode([NetworkRecord].self, from: Data(json.utf8))
        XCTAssertEqual(networks[0].name, "default")
        XCTAssertTrue(networks[0].isBuiltin)
        XCTAssertEqual(networks[0].status?.ipv4Subnet, "192.168.64.0/24")
    }

    func testDecodeSystemStatus() throws {
        let json = """
        {"apiServerAppName":"container-apiserver","apiServerBuild":"release",
        "apiServerCommit":"unspecified","apiServerVersion":"1.0.0",
        "appRoot":"/Users/x","installRoot":"/opt/homebrew","status":"running"}
        """
        let status = try JSONDecoder().decode(SystemStatus.self, from: Data(json.utf8))
        XCTAssertTrue(status.isRunning)
    }

    func testRunOptionsBuildArguments() {
        var options = RunOptions()
        options.image = "nginx:latest"
        options.name = "web"
        options.ports = "8080:80, 8443:443"
        options.volumes = "data:/var/lib"
        options.environment = "FOO=bar\nBAZ=qux\n"
        options.cpus = "2"
        options.memory = "512m"
        options.removeOnExit = true
        options.command = "nginx -g daemon off;"

        let args = options.buildArguments()
        XCTAssertEqual(args.first, "run")
        XCTAssertTrue(args.contains("--detach"))
        XCTAssertTrue(args.contains("--rm"))
        XCTAssertEqual(args.filter { $0 == "--publish" }.count, 2)
        XCTAssertTrue(args.contains("8080:80"))
        XCTAssertTrue(args.contains("data:/var/lib"))
        XCTAssertTrue(args.contains("FOO=bar"))
        XCTAssertTrue(args.contains("BAZ=qux"))
        XCTAssertTrue(args.contains("512m"))
        // Image comes before the command.
        let imageIndex = args.firstIndex(of: "nginx:latest")!
        let commandIndex = args.firstIndex(of: "nginx")!
        XCTAssertLessThan(imageIndex, commandIndex)
    }

    func testRunOptionsMinimal() {
        var options = RunOptions()
        options.image = "alpine:latest"
        XCTAssertEqual(options.buildArguments(), ["run", "--detach", "alpine:latest"])
    }

    func testFormatters() {
        XCTAssertNotNil(Formatters.date(fromISO: "2026-07-04T04:07:35Z"))
        XCTAssertNotNil(Formatters.date(fromISO: "2026-06-16T00:01:29.967161902Z"))
        XCTAssertNil(Formatters.date(fromISO: nil))
        XCTAssertEqual(Formatters.bytes(nil), "—")
        XCTAssertEqual(Formatters.bytes(0), "—")
    }

    func testPrettyPrint() {
        let pretty = ContainerCLI.prettyPrint(#"{"b":1,"a":2}"#)
        XCTAssertTrue(pretty.contains("\n"))
        // Invalid JSON passes through untouched.
        XCTAssertEqual(ContainerCLI.prettyPrint("not json"), "not json")
    }
}
