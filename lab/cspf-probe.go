package main

import (
	"fmt"
	"log"
	"strings"

	pb "github.com/nttcom/pola/api/pola/v1"
	polagrpc "github.com/nttcom/pola/cmd/pola/grpc"
	"github.com/nttcom/pola/pkg/cspf"
	"github.com/nttcom/pola/pkg/table"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	conn, err := grpc.NewClient("127.0.0.1:50052", grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()
	ted, err := polagrpc.GetTED(pb.NewPCEServiceClient(conn))
	if err != nil || ted == nil {
		log.Fatalf("GetTED: ted=%v err=%v", ted, err)
	}
	links := 0
	for _, node := range ted.Nodes {
		links += len(node.Links)
	}
	fmt.Printf("TED nodes=%d directed-links=%d\n", len(ted.Nodes), links)

	const source = "1920.0000.2001"
	const destination = "1920.0000.2004"
	const p2 = "1920.0000.2003"
	planes := []table.Plane{
		{Family: table.AFIPv4, DataPlane: table.DPSRMPLS},
		{Family: table.AFIPv6, DataPlane: table.DPSRMPLS},
		{Family: table.AFIPv6, DataPlane: table.DPSRv6},
	}
	metrics := []table.MetricType{table.IGPMetric, table.TEMetric, table.HopcountMetric, table.DelayMetric}
	for _, plane := range planes {
		scope := cspf.PathScope{Plane: plane}
		for _, metric := range metrics {
			segments, err := cspf.CSPF(source, destination, metric, scope, ted)
			fmt.Printf("%s/%s %s direct %s\n", plane.Family, plane.DataPlane, metric.DisplayString(), result(segments, err))
		}
		segments, err := cspf.WithLooseSourceRouting(source, destination, []table.Waypoint{{RouterID: p2}}, table.IGPMetric, scope, ted)
		fmt.Printf("%s/%s igp via-p2 %s\n", plane.Family, plane.DataPlane, result(segments, err))
	}
}

func result(segments []table.Segment, err error) string {
	if err != nil {
		return fmt.Sprintf("error=%v", err)
	}
	sids := make([]string, 0, len(segments))
	for _, segment := range segments {
		sids = append(sids, segment.SidString())
	}
	return "segments=" + strings.Join(sids, ",")
}
