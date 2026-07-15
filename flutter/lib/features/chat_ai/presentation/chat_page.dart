import 'package:finance_ai/core/services/supabase_web_client.dart';
import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget { const ChatPage({super.key}); @override State<ChatPage> createState()=>_ChatPageState(); }
class _ChatPageState extends State<ChatPage> {
  final input=TextEditingController(); final messages=<String>[]; String? token;
  Future<void> send() async { final text=input.text.trim(); if(text.isEmpty)return; setState((){messages.add('Você: $text');input.clear();}); if(token==null){setState(()=>messages.add('Entre para enviar comandos à IA.'));return;} try{final data=await SupabaseWebClient.instance.chat(token!,{'message':text,'idempotencyKey':'00000000-0000-4000-8000-000000000001'});setState(()=>messages.add('Finance AI: ${data['action']}'));}catch(_){setState(()=>messages.add('Não foi possível consultar a IA.'));}}
  @override Widget build(BuildContext context)=>Column(children:[Expanded(child:ListView(children:[const Padding(padding:EdgeInsets.all(24),child:Text('Como posso ajudar com suas finanças?')),...messages.map((m)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Text(m))))])),Padding(padding:const EdgeInsets.all(16),child:Row(children:[Expanded(child:TextField(controller:input,onSubmitted:(_)=>send(),decoration:const InputDecoration(hintText:'Ex.: Gastei R\$ 50 no mercado'))),FilledButton(onPressed:send,child:const Text('Enviar'))]))]);
}
