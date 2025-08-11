
import { WebSocketGateway, WebSocketServer, OnGatewayInit } from '@nestjs/websockets';
import { Server } from 'socket.io';

@WebSocketGateway({ cors: { origin: true, credentials: true }, path: '/realtime' })
export class EventsGateway implements OnGatewayInit {
  @WebSocketServer() server!: Server;
  afterInit() { /* ready */ }

  broadcast(projectId: string, event: string, data: any) {
    this.server.to(`project:${projectId}`).emit(event, data);
  }

  handleConnection(client: any) {
    const projectId = client.handshake.query.projectId;
    if (projectId) client.join(`project:${projectId}`);
  }
}
